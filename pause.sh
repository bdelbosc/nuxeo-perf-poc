#!/bin/bash

cd $(dirname $0)
set -e
. venv/bin/activate

function pause() {
  pushd ansible
  export ANSIBLE_HOST_KEY_CHECKING=False
  ansible-playbook -i inventory.py -v ./pause.yml
  popd
}

# ------------------------------
# main
pause
