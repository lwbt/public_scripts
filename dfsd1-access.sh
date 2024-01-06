#!/bin/bash

generate_ssh_keys() {

  # Provide a customizable default value and ask for user confirmation.
  read -rei "${HOSTNAME}" \
    -p "Used hostname [Customize if necessary.]: " hostname

  # shellcheck disable=SC2043
  for key_type in "ed25519"; do

    for repo in "dotfiles_steamdeck" "bash_scripts" "steam-grids"; do

      dk_file="${HOME}/.ssh/dk_${key_type}__${repo}"

      [[ -f "${dk_file}" ]] && rm -iv "${dk_file}"

      ssh-keygen -t "${key_type}" -N '' \
        -C "${USER}@${hostname}-$(date +%F)-dk-${repo}" \
        -f "${dk_file}" \
        | head -n 5 \
        | tail -n 3

    done

  done
}

# Copy the public key files to external storage.
# Using a service like paste bin has been considered unsafe.
copy_public_keys() {

  # Display an overview of currently mounted media.
  # Note: -e7 suppresses loop mounts, which are used a lot by Snapd on Ubuntu
  lsblk -e7

  # Provide a customizable default value and ask for user confirmation.
  read -rei "/run/media/mmcblk0p1" \
    -p "Copy SSH public keys to removable media in this path: " ssh_pub_path

  cp -v "${HOME}/.ssh/dk_"*".pub" "${ssh_pub_path}"
}

# Setup "${HOME}/.ssh/config"
configure_ssh_client() {

  # Configure subdirectory for configuration fragments.
  mkdir -pv "${HOME}/.ssh/config.d"

  # Ensure correct permissions are set.
  chmod --changes 700 \
    "${HOME}/.ssh/" \
    "${HOME}/.ssh/config.d/"

  # Backup existing configuration.
  if [[ -f "${HOME}/.ssh/config" ]]; then
    mv -v "${HOME}/.ssh/config" \
      "${HOME}/.ssh/config.d/backup_$(date +%F_%T).conf.bak"
  fi

  # Configure stanza for configuration fragments in subdirectory.
  cat << 'EOF' > "${HOME}/.ssh/config"
# Has to be '~', because '%d' did not work.
Include ~/.ssh/config.d/*.conf
EOF

  # Hosts for Steam Deck dotfile deploy keys.
  cat << 'EOF' > "${HOME}/.ssh/config.d/dotfile_hosts.conf"
# Hosts for Steam Deck dotfile deploy keys.
Host github.com-dotfiles-steamdeck
  Hostname github.com
  # %d = user's home directory; see man ssh_config
  IdentityFile=%d/.ssh/dk_ed25519__dotfiles_steamdeck

Host github.com-bash-scripts
  Hostname github.com
  IdentityFile=%d/.ssh/dk_ed25519__bash_scripts

Host github.com-steam-grids
  Hostname github.com
  IdentityFile=%d/.ssh/dk_ed25519__steam-grids
EOF
}

main() {

  generate_ssh_keys

  copy_public_keys

  configure_ssh_client
}

main "$@"
