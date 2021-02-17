#!/bin/bash
set -e -o pipefail
cd $(dirname $(realpath "${0}"))

SERVER_URL=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
SOCAT_SERVICE_PORT=9999

SERVER_IP=${SERVER_URL#https://}
SERVER_IP=${SERVER_IP//:*/}

echo >&2 "Starting service at port ${SOCAT_SERVICE_PORT}"
echo >&2 "To enroll a new node paste the command below:"
echo >&2 "  echo \$(hostname) | socat TCP:${SERVER_IP}:${SOCAT_SERVICE_PORT} STDIO | base64 -d | tar -xzvC /"

exec socat "TCP-LISTEN:${SOCAT_SERVICE_PORT},reuseaddr,crlf,fork" SYSTEM:'read nodename; exec ./gencred-agent.sh "${nodename}"'
