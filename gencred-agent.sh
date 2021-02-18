#!/bin/bash
set -e -o pipefail
cd $(dirname $(realpath "${0}"))

if [ $# -ne 1 ]; then
    echo >&2 "Usage: ${0} <node-name>"
    exit 1
fi

node_name="${1}"

## Resolve and export server address
SERVER_ADDRESS=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
SERVER_ADDRESS=${SERVER_ADDRESS#https://}
SERVER_ADDRESS=${SERVER_ADDRESS//:*/}
export SERVER_ADDRESS

## Temporary output directory
output_dir=$(mktemp -d)
trap 'rm -rf ${output_dir}' TERM INT EXIT

## RootFS
rootfs_dir="${output_dir}/rootfs"
kubernetes_dir="${rootfs_dir}/etc/kubernetes"
node_bundle_dir="${rootfs_dir}/node-bundle"
spire_conf_dir="${node_bundle_dir}/spire/conf"

## Prepare essential folders and resources
mkdir -p "${spire_conf_dir}"
cp -r "spire/conf/agent" "${spire_conf_dir}"
envsubst < "spire/conf/agent/agent.conf" > "${spire_conf_dir}/agent/agent.conf"

mkdir -p "${kubernetes_dir}/manifests" "${kubernetes_dir}/pki"
cp "kubernetes/manifests/spire-agent.yaml" "${kubernetes_dir}/manifests/"
cp "/etc/kubernetes/pki/ca.crt" "${kubernetes_dir}/pki/ca.crt"

## SPIRE Agent binary and authn-plugin
mkdir -p "${rootfs_dir}/opt/spire/bin"
cp "/opt/spire/bin/spire-agent" "${rootfs_dir}/opt/spire/bin/spire-agent"
cp "/bundle/spire-authn-plugin.sh" "${node_bundle_dir}/spire-authn-plugin.sh"

## Generate kubelet config
CA_DATA=$(base64 -w0 "/bundle/spire/conf/server/dummy_upstream_ca.crt")
cat <<EOF > ${rootfs_path}/etc/kubernetes/kubelet.conf
apiVersion: v1
kind: Config

clusters:
- name: kubernetes
  cluster:
    certificate-authority-data: ${CA_DATA}
    server: https://$(hostname):5443/

current-context: system:node:${node_name}@kubernetes
contexts:
- name: system:node:${node_name}@kubernetes
  context:
    cluster: kubernetes
    user: system:node:${node_name}

users:
- name: system:node:${node_name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: /node-bundle/spire-authn-plugin.sh
EOF

## Generate keys
openssl req -newkey rsa:2048 -nodes                     \
    -out    "${output_dir}/x509pop_user.csr"            \
    -keyout "${spire_conf_dir}/agent/x509pop_user.key"  \
    -subj   "/CN=${node_name}"

openssl x509 -req -CAcreateserial                       \
    -in    "${output_dir}/x509pop_user.csr"             \
    -out   "${spire_conf_dir}/agent/x509pop_user.crt"   \
    -CA    "/bundle/spire/conf/server/x509pop_ca.crt"   \
    -CAkey "/bundle/spire/conf/server/x509pop_ca.key"   \
    -extfile <(echo keyUsage=digitalSignature)          \
    -days 3650

## Create provisioning bundle
tar -czC "${rootfs_dir}" . | base64 -w0
