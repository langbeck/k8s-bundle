#!/bin/sh
set -e

REGISTRATION_UDS_PATH="${REGISTRATION_UDS_PATH:-/tmp/spire-registration.sock}"

# Fallback path to use when running inside SPIRE's containers
export PATH=${PATH}:/opt/spire/bin

entry_show() {
    spire-server entry show -registrationUDSPath "${REGISTRATION_UDS_PATH}" "${@}"
}

entry_delete() {
    spire-server entry delete -registrationUDSPath "${REGISTRATION_UDS_PATH}" "${@}"
}

entry_create() {
    spire-server entry create -registrationUDSPath "${REGISTRATION_UDS_PATH}" "${@}"
}

agent_show() {
    spire-server agent show -registrationUDSPath "${REGISTRATION_UDS_PATH}" "${@}"
}

agent_list() {
    spire-server agent list -registrationUDSPath "${REGISTRATION_UDS_PATH}" "${@}"
}

entry_show | awk '/^Entry ID/{ print $4 }' | while read entryID; do
    entry_delete -entryID "${entryID}" > /dev/null
done

agent_list | awk '/^Spiffe ID/ { print $4 }' | while read parentID; do
    node_name=$(agent_show -spiffeID "${parentID}" | sed -nr 's/^Selectors +: +x509pop:subject:cn:(.*)$/\1/p')
    echo ${node_name}
    if [ "${node_name}" = "$(hostname)" ]; then
        spiffeID="spiffe://example.org/k8s-proxy"
        entry_create -parentID "${parentID}" -spiffeID "${spiffeID}"        \
            -selector "unix:path:/usr/bin/authn-proxy"                      \
            -dns "${node_name}"
    fi

    spiffeID="spiffe://example.org/k8s-user/system:node:${node_name}/system:nodes"
    entry_create -parentID "${parentID}" -spiffeID "${spiffeID}"        \
        -selector "unix:path:/opt/spire/bin/spire-agent"
done
