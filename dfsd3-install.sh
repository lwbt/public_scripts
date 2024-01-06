#!/bin/bash

install_chezmoi() {

  # Provide a customizable default value and ask for user confirmation.
  read -rei "lwbt/dotfiles_steamdeck_public" -p "Repo: " gh_repo_dotfiles

  # TODO: Is this still necessary?
  mkdir -pv "${HOME}/.config/chezmoi"
  cat << 'EOF' >> "${HOME}/.config/chezmoi/chezmoi.toml"
[template]
    options = ["missingkey=zero"]
EOF

  # Install Chezmoi to an alternate directory for consistency with pipx and
  # others.
  export BINDIR="${HOME}/.local/bin"

  # Setup "~/.local/bin" folder if necessary before installing chezmoi.
  mkdir -pv "${BINDIR}" \
    && if ! grep -c "${BINDIR}" <<< "${PATH}"; then

      # shellcheck disable=SC2016
      echo 'PATH="${HOME}/.local/bin:${PATH}"' >> "${HOME}/.profile"
    fi

  sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --ssh --verbose \
    --interactive \
    "git@github.com-dotfiles-steamdeck:${gh_repo_dotfiles}.git"
}

main() {

  install_chezmoi
}

main "$@"
