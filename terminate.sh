#!/bin/bash
cd $(dirname $0)
set -e

. venv/bin/activate

function terminate() {
  pushd ansible
  export ANSIBLE_HOST_KEY_CHECKING=False
  ansible-playbook -i inventory.py -v ./terminate.yml
  popd
}

confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

# ------------------------------
# main
confirm && terminate

