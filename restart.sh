#!/bin/bash

cd $(dirname $0)
set -e
. venv/bin/activate

function restart() {
  pushd ansible
  export ANSIBLE_HOST_KEY_CHECKING=False
  set -x
  ansible-playbook -i inventory.py ./stop.yml "$@"
  ansible-playbook -i inventory.py ./start.yml "$@"
  popd
}

# ------------------------------
# main
restart "$@"
