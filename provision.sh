#!/bin/bash
# Provision all aws necessary resources
cd $(dirname $0)
HERE=`readlink -e .`

function setup_ansible() {
  if [ ! -d venv ]; then
    virtualenv venv
  fi
  . venv/bin/activate
  pip3 install -q -r ansible/requirements.txt
  # prevent ssh auth checking fingerprints
  export ANSIBLE_HOST_KEY_CHECKING=False
  export ANSIBLE_PIPELINING=True
  export ANSIBLE_RETRIES=2
  export ANSIBLE_TIMEOUT=60
}

function run_ansible() {
  pushd ansible
  # --limit nuxeo
  #  --tags "hh"
  set -x
  ansible-playbook -i inventory.py -vv provisioning.yml
  popd
}

# main -----------------------------------------
#
setup_ansible
run_ansible
