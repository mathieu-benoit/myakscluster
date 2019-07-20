#!/bin/bash

az login --service-principal -u $SP_ID -p $SP_SECRET --tenant $SP_TENANT_ID
az account set -s $SUBSCRIPTION_ID
      
# Accelerated Networking check
nodeResourceGroup=$(az aks show -g $RG -n $AKS --query nodeResourceGroup -o tsv)
for nic in $(az resource list -g $nodeResourceGroup --resource-type Microsoft.Network/networkInterfaces --query [].name -o tsv)
do 
      enabled=$(az network nic show -g $nodeResourceGroup -n $nic --query "enableAcceleratedNetworking")
      if [ $enabled = "true" ]; then
            1>&2 echo "AcceleratedNetworking not enabled"
      fi 
done
        
