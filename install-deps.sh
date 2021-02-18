#!/bin/bash
set -e -o pipefail

yum install -y openssl gettext

mkdir -p /opt/spire
curl -L https://github.com/spiffe/spire/releases/download/v0.10.0/spire-0.10.0-linux-x86_64-glibc.tar.gz |\
    tar --strip-components=2 -xzC /opt/spire
