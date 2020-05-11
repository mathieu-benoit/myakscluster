#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

# Read input
eval "$(jq -r '@sh "rg=\(.rg) privateEndpointName=\(.privateEndpointName)"')"

networkInterfaceId=$(az network private-endpoint show \
  -n $privateEndpointName \
  -g $rg \
  --query 'networkInterfaces[0].id' \
  --output tsv)
acrPrivateEndpointPrivateIp=$(az resource show \
  --ids $networkInterfaceId \
  --api-version 2019-04-01 --query 'properties.ipConfigurations[1].properties.privateIPAddress' \
  --output tsv)

# Write output
jq -n --arg acrPrivateEndpointPrivateIp "$acrPrivateEndpointPrivateIp" '{"acr_private_endpoint_private_ip":$acrPrivateEndpointPrivateIp}'