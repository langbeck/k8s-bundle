#!/bin/bash
set -e -o pipefail
cd $(dirname $(realpath "${0}"))

echo >&2 "Provisioning spire-agent credentials..."
./gencred-agent.sh $(hostname) | base64 -d | tar -xzC /

echo >&2 "Copying spire manifests..."
rm -f /etc/kubernetes/manifests/spire-*.yaml
cp kubernetes/manifests/spire-*.yaml /etc/kubernetes/manifests/
