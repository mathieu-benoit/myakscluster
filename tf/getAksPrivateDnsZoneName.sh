#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

# Read input
eval "$(jq -r '@sh "aksNodesResourceGroup=\(.aksNodesResourceGroup)"')"

aksPrivateDnsZone=$(az network private-dns zone list \
    -g $aksNodesResourceGroup \
    --query [0].name \
    -o tsv)

# Write output
jq -n --arg aksPrivateDnsZone "$aksPrivateDnsZone" '{"aks_private_dns_zone":$aksPrivateDnsZone}'