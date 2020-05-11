#!/bin/bash

az login --service-principal -u $SP_ID -p $SP_SECRET --tenant $SP_TENANT_ID
az account set -s $SUBSCRIPTION_ID
      
# Accelerated Networking check
nodeResourceGroup=$(az aks show -g $RG -n $AKS --query nodeResourceGroup -o tsv)
nodesVmss=$(az vmss list -g $nodeResourceGroup -o tsv --query [0].name)
for enabled in $(az vmss nic list -g $nodeResourceGroup --vmss-name $nodesVmss --query [].enableAcceleratedNetworking -o tsv)
do 
      if [ $enabled = "false" ]; then
            1>&2 echo "AcceleratedNetworking not enabled"
      fi 
done
