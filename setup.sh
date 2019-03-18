#!/bin/bash
# Setup the provisioned instances
set -e
cd $(dirname $0)

function setup_ansible() {
  . venv/bin/activate
  # prevent ssh auth checking fingerprints
  export ANSIBLE_HOST_KEY_CHECKING=False
  export ANSIBLE_PIPELINING=True
  export ANSIBLE_RETRIES=2
  export ANSIBLE_TIMEOUT=60
}

function setup() {
  pushd ansible
  # --limit nuxeo
  #  --tags "hh"
  set -x
  ansible-playbook -i inventory.py -vv setup.yml
  popd
}

# main -----------------------------------------
#
setup_ansible
setup
