#!/bin/bash
set -e -o pipefail

output_dir=$(mktemp -d)
trap 'rm -rf ${output_dir}' EXIT INT TERM

/opt/spire/bin/spire-agent api fetch x509 -write "${output_dir}" > /dev/null

certificate_data=$(awk '{printf $0"\\n"}' "${output_dir}/svid.0.pem")
key_data=$(awk '{printf $0"\\n"}' "${output_dir}/svid.0.key")

cat <<EOF
{
  "apiVersion": "client.authentication.k8s.io/v1beta1",
  "kind": "ExecCredential",
  "status": {
    "clientCertificateData": "${certificate_data}",
    "clientKeyData": "${key_data}"
  }
}
EOF
