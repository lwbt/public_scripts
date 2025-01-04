#!/bin/bash

# A convenience script for using asciinema.

# shellcheck disable=SC2034
VERSION="v2024-02-20"

# Menu items for asciinema commands.
# This also defines the ordering of menu items and serves as a help/usage text.
ASCMA_ITEMS="
COMMAND;EXPLANATION\n
record;Record a terminal session with asciinema\n
play;Play recordings with asciinema\n
install;Install asciinema locally\n
auth;Authenticate local system to asciinema.org\n
upload;Upload recordings to asciinema.org\n
"

# Calculate the height of the menu.
# Why 3? Top, Bottom, HEADER = 3
ASCMA_ITEMS_HEIGHT=$(($(echo "${ASCMA_ITEMS}" | wc -l) - 3))

# Minimal set of colors and styles.
export BGRED="\033[41m"
#export BGWHITE="\033[107m"
#export FGRED="\033[31m"
#export FGWHITE="\033[97m"
#export INV="\033[7m"
export NC="\033[0m"

# Display an error message passed as parameters with a timestamp.
#
# Usage advice for longer messages:
#
#   err_fatal \
#     "First line.\n" \
#     "Second line."
#
err() {
  echo >&2 -e "${BGRED}ERR${NC} $(date --rfc-3339=sec):\n $*"
}

# Function for printing fatal error messages and aborting script execution
err_fatal() {
  echo >&2 -e "${BGRED}ERR${NC} $(date --rfc-3339=sec):\n $*"
  echo >&2 "Aborting."
  exit 1
}

# Function to check if a command is available $1 = command name.
test_command() {
  command -v "$1" > /dev/null 2>&1
}

# Detect the OS. If os-release does not exist, then the Linux distribution is
# considered not to be supported. It's just a simple file.
detect_os() {
  # Checking for MacOS and Windows, unsupported
  case "$OSTYPE" in
    "darwin"*)
      err_fatal "MacOS is not supported yet."
      ;;
    "cygwin" | "msys")
      err_fatal "Windows/Cygwin/Git-Bash is not supported yet."
      ;;
  esac

  # Sourcing OS release information for Linux distributions
  if [[ -r "/etc/os-release" ]]; then
    # Triggers SC1091 -- disabled to pacify pre-commit
    # shellcheck disable=SC1091
    source "/etc/os-release"
  else
    err_fatal "Unknown Linux distribution!"
  fi
}

# Function to detect if pipx is installed, if not attempt to install it.
detect_pipx() {
  if ! test_command "pipx"; then
    err "Please install pipx. See: https://github.com/pypa/pipx"
    install_pipx
  fi
}

# Function to detect if 'gum' is available, necessary for some functions
detect_gum_fatal() {
  if ! test_command "gum"; then
    err_fatal \
      "Sorry, this function requires 'gum' for convenient file browsing.\n" \
      "See: https://github.com/charmbracelet/gum#installation"
  fi
}

# Show commands to install pipx, and offer to perform the installation.
# Only currently supported operating systems with supported versions of Python
# 3 are supported. Any end of life (EOL) versions are not considered. This
# section is already long enough.
install_pipx() {

  local confirm_action

  # Install the pipx package provided by Ubuntu on Ubuntu 23.04 and above.
  if [[ "${ID}" == "ubuntu" && "${VERSION_ID/.[0-9][0-9]/}" -ge 23 ]]; then

    # Installation steps for Ubuntu
    echo "sudo apt update"
    echo "sudo apt install pipx"
    echo "pipx ensurepath"

    # Asking for confirmation before performing installation
    read -rei "Yes" \
      -p "> Do you want to perform the actions above? " confirm_action

    if [[ "${confirm_action}" == "Yes" ]]; then

      sudo apt update
      sudo apt install pipx
      pipx ensurepath

    fi

  # Install through python.
  else

    echo "python3 -m ensurepip --upgrade"
    echo "python3 -m pip install --user pipx"
    echo "python3 -m pipx ensurepath"

    # Asking for confirmation before performing installation
    read -rei "Yes" \
      -p "> Do you want to perform the actions above? " confirm_action

    if [[ "${confirm_action}" == "Yes" ]]; then

      python3 -m ensurepip --upgrade
      python3 -m pip install --user pipx
      python3 -m pipx ensurepath

    fi
  fi
}

# Function to detect XDG folders and set up the recordings folder for asciinema
detect_xdg_folders() {
  [[ ! -r "${HOME}/.config/user-dirs.dirs" ]] && err_fatal \
    "'~/.config/user-dirs.dirs' is not readable or does not exist!"

  # Triggers SC1091 -- disabled to pacify pre-commit
  # shellcheck disable=SC1091
  source "${HOME}/.config/user-dirs.dirs"

  RECORDINGS_FOLDER="${XDG_VIDEOS_DIR}/ASCIINEMA"
  readonly RECORDINGS_FOLDER

  # Creating recordings folder if it doesn't exist
  if [[ ! -d "${RECORDINGS_FOLDER}" ]]; then
    mkdir -pv "${RECORDINGS_FOLDER}"
  fi

  echo "Using ${RECORDINGS_FOLDER} for recordings."
}

# Function to choose the idle time limit for asciinema recordings
asciinema_choose_idle_time() {
  # Setting up options for choosing idle time
  GUM_CHOOSE_HEADER="Choose idle time limit:"
  GUM_CHOOSE_SELECTED="2"
  export GUM_CHOOSE_SELECTED
  export GUM_CHOOSE_HEADER

  # Asking user to choose idle time
  idle_time="$(gum choose "none" "2" "3" "4" "5" "10")"

  unset GUM_CHOOSE_HEADER
  unset GUM_CHOOSE_SELECTED

  # Determining idle time based on user input
  case "${idle_time}" in
    [0-9] | [0-9][0-9])
      idle_time="--idle-time-limit=${idle_time}"
      ;;
    "none")
      idle_time=""
      ;;
    *)
      err_fatal "Not supported input for idle time."
      ;;
  esac

  echo -e "Choose idle time limit:\n${idle_time}"
}

# Record terminal sessions with asciinema in a consistent location with
# consistent file naming scheme.
asciinema_record() {
  local asciinema_filename_tmp
  asciinema_filename_tmp="asciinema_$(date +%F_%H%M%S).cast"
  local asciinema_filename
  local -x idle_time

  # Asking for filename for the recording
  if test_command "gum"; then
    GUM_INPUT_HEADER="File name:"
    export GUM_INPUT_HEADER

    asciinema_filename=$(gum input --value="${asciinema_filename_tmp}")

    unset GUM_INPUT_HEADER
  else
    echo "File name:"
    read -rei "${asciinema_filename_tmp}" -p "> " asciinema_filename
  fi

  [[ -z "${asciinema_filename}" ]] && err_fatal "No valid file name selected!"

  asciinema_filename="${RECORDINGS_FOLDER}/${asciinema_filename}"

  # Choosing idle time for the recording
  asciinema_choose_idle_time

  # Record a terminal session.
  if test_command "asciinema"; then
    if [[ -z "${idle_time}" ]]; then
      asciinema rec "${asciinema_filename}"
    else
      asciinema rec "${idle_time}" "${asciinema_filename}"
    fi
  else
    if [[ -z "${idle_time}" ]]; then
      pipx run asciinema rec "${asciinema_filename}"
    else
      pipx run asciinema rec "${idle_time}" "${asciinema_filename}"
    fi
  fi

}

# Function to select an asciinema recording file for playback
asciinema_select_file() {
  if [[ -d "${RECORDINGS_FOLDER}" ]]; then

    echo "Select a file for playback:"

    # Using 'gum' to select an asciinema recording file
    asciinema_filename=$(gum file --height 25 "${RECORDINGS_FOLDER}")
    [[ -z "${asciinema_filename}" ]] && err_fatal "No file selected!"

    echo "${asciinema_filename}"

  else
    err_fatal "Folder '${RECORDINGS_FOLDER}' not found!"
  fi
}

# Function to choose playback speed for asciinema recordings
asciinema_choose_playback_speed() {
  # Setting up options for choosing playback speed
  GUM_CHOOSE_HEADER="Choose a playback speed:"
  GUM_CHOOSE_SELECTED="1"
  export GUM_CHOOSE_SELECTED
  export GUM_CHOOSE_HEADER

  # Asking user to choose playback speed
  playback_speed="$(
    gum choose "0.5" "0.75" "1" "1.25" "1.5" "1.75" "2" "2.5" "3"
  )"

  unset GUM_CHOOSE_HEADER
  unset GUM_CHOOSE_SELECTED

  [[ -z "${playback_speed}" ]] && playback_speed=1

  echo -e "Choose a playback speed:\n${playback_speed}"
}

# Play asciinema recordings while providing a convenient file browser.
asciinema_play() {
  local -x playback_speed
  local -x asciinema_filename
  detect_gum_fatal

  echo ""
  echo "Keyboard shortcuts:"
  echo " SPACE = Pause/Resume"
  echo " ]     = Jump to next marker"
  echo " .     = Step (when paused)"
  echo ""

  # Select a file to play.
  asciinema_select_file

  # Choose a playback speed for the file to play.
  asciinema_choose_playback_speed

  echo "Start playing selected file!"

  # Play the selected file.
  if test_command "asciinema"; then
    asciinema play --speed="${playback_speed}" "${asciinema_filename}"
  else
    pipx run asciinema play --speed="${playback_speed}" "${asciinema_filename}"
  fi
}

# Upload asciinema recordings while providing a convenient file browser.
asciinema_upload() {
  local -x asciinema_filename
  detect_gum_fatal

  echo "NOTE: Anonymous recordings are automatically deleted after 7 days."

  # Select a file to upload.
  asciinema_select_file

  # Upload the selected file.
  if test_command "asciinema"; then
    asciinema upload "${asciinema_filename}"
  else
    pipx run asciinema upload "${asciinema_filename}"
  fi
}

# Authenticate local system with asciinema.org.
asciinema_auth() {
  if test_command "asciinema"; then
    asciinema auth
  else
    pipx run asciinema auth
  fi
}

# Main function
main() {
  detect_os
  detect_pipx
  detect_xdg_folders

  # Determining program name based on script filename
  #
  # This concept may be difficult to grasp and may seem unnecessary expense up
  # front. But as soon as you realize that you can jump to specific
  # functionality in this code through clever and robust structuring of the code
  # simply by identifying the file name it was called from (and using
  # symlinks), you can reap the benefits of maintaining only one very good
  # script, instead of plenty mediocre ones.
  #
  program_name="$(basename -s ".sh" "${BASH_SOURCE[0]}")"
  readonly program_name
  case "${program_name}" in

    "asciinema" | "asciinema-helper")
      detect_gum_fatal

      # Presenting a menu of available commands using 'gum'
      SELECTION="$(echo -e "${ASCMA_ITEMS}" \
        | gum table -s ";" -w 15,65 --height ${ASCMA_ITEMS_HEIGHT})"
      echo "${SELECTION##*;}"
      ;;

    "asciinema-record" | "asciinema-play" | "asciinema-install" | \
      "asciinema-auth" | "asciinema-upload")
      SELECTION="${program_name/-/_}"
      ;;

    *) err_fatal "Error, ${program_name} not defined!" ;;
  esac

  # TODO: This was created while we only had input from from `gum table`.
  # It may need refactoring or a good explanation.
  case "${SELECTION%%;*}" in
    "asciinema_record" | "record")
      asciinema_record
      ;;
    "asciinema_play" | "play")
      asciinema_play
      ;;
    "asciinema_install" | "install")
      pipx install asciinema
      ;;
    "asciinema_auth" | "auth")
      asciinema_auth
      ;;
    "asciinema_upload" | "upload")
      asciinema_upload
      ;;
    *) err_fatal "Error, ${SELECTION%%;*} not defined!" ;;
  esac
}

main "$@"
