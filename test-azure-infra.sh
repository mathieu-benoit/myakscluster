#!/bin/bash

az login --service-principal -u $SP_ID -p $SP_SECRET --tenant $SP_TENANT_ID
az account set -s $SUBSCRIPTION_ID
      
nodeResourceGroup=$(az aks show -g mabenoitaks -n mabenoitaks --query nodeResourceGroup -o tsv)
az resource list -g $nodeResourceGroup --resource-type Microsoft.Network/networkInterfaces --query [].name
az network nic show -g $nodeResourceGroup -n <nic-name> --query "enableAcceleratedNetworking"
