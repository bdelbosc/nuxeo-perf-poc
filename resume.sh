#!/bin/bash
cd $(dirname $0)
set -e

. venv/bin/activate

function resume() {
  pushd ansible
  export ANSIBLE_HOST_KEY_CHECKING=False
  ansible-playbook -i inventory.py -v ./resume.yml
  popd
}

# ------------------------------
# main
resume

