#!/bin/bash
set -e -o pipefail
cd $(dirname $(realpath "${0}"))

if [ $# -ne 1 ]; then
    echo >&2 "Usage: ${0} <node-name>"
    exit 1
fi

node_name="${1}"

## Temporary output directory
output_dir=$(mktemp -d)
trap 'rm -rf ${output_dir}' TERM INT EXIT

## RootFS
rootfs_dir="${output_dir}/rootfs"
kubernetes_dir="${rootfs_dir}/etc/kubernetes"
spire_conf_dir="${rootfs_dir}/bundle/spire/conf"

## Prepare essential folders and resources
mkdir -p "${spire_conf_dir}"
cp -r "spire/conf/agent" "${spire_conf_dir}"

mkdir -p "${kubernetes_dir}/manifests" "${kubernetes_dir}/pki"
cp "kubernetes/manifests/spire-agent.yaml" "${kubernetes_dir}/manifests/"
cp "/etc/kubernetes/pki/ca.crt" "${kubernetes_dir}/pki/ca.crt"

## Generate keys
openssl req -newkey rsa:2048 -nodes                         \
    -out    "${output_dir}/x509pop_user.csr"                \
    -keyout "${spire_conf_dir}/agent/x509pop_user.key"      \
    -subj   "/CN=${node_name}"

openssl x509 -req -CAcreateserial                           \
    -in    "${output_dir}/x509pop_user.csr"                 \
    -out   "${spire_conf_dir}/agent/x509pop_user.crt"       \
    -CA    "/node-bundle/spire/conf/server/x509pop_ca.crt"  \
    -CAkey "/node-bundle/spire/conf/server/x509pop_ca.key"  \
    -extfile <(echo keyUsage=digitalSignature)              \
    -days 3650

## Create provisioning bundle
tar -czC "${rootfs_dir}" . | base64 -w0
