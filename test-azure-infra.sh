#!/bin/bash

az login --service-principal -u $SP_ID -p $SP_SECRET --tenant $SP_TENANT_ID
az account set -s $SUBSCRIPTION_ID
      
# Accelerated Networking check
nodeResourceGroup=$(az aks show -g $RG -n $AKS --query nodeResourceGroup -o tsv)
for nic in $(az resource list -g $nodeResourceGroup --resource-type Microsoft.Network/networkInterfaces --query [].name -o tsv)
do 
      enabled=$(az network nic show -g $nodeResourceGroup -n $nic --query "enableAcceleratedNetworking")
      if [ $enabled = "false" ]; then
            1>&2 echo "AcceleratedNetworking not enabled"
      fi 
done

# LB check
loadBalancerSku=$(az aks show -g $RG -n $AKS --query networkProfile.loadBalancerSku -o tsv)
if [ $STANDARD_LOAD_BALANCER = "true" ]
then
      if [ $loadBalancerSku = "Basic" ]; then
            1>&2 echo "AcceleratedNetworking not enabled"
      fi
else
      if [ $loadBalancerSku = "Standard" ]; then
            1>&2 echo "LoadBalancerSku not found as expected"
      fi
fi
