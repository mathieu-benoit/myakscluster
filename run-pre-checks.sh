#!/bin/bash

az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.KubernetesConfiguration

# Zones
if [[ $ZONES = "true" ]]; then
      azLocations=(centralus eastus eastus2 westus2 francecentral northeurope uksouth westeurope japaneast southeastasia)
      if [[ ! " ${azLocations[@]} " =~ " ${LOCATION} " ]]; then
            1>&2 echo "The location you selected doesn't support Availability Zones!"
      fi
fi

# VM quota
vmFamily=$(az vm list-skus -l $LOCATION -s $NODE_SIZE --query [0].family -o tsv)
az vm list-usage -l $LOCATION --query "[?name.value=='$vmFamily']"
quotaCurrentValue=$(az vm list-usage -l $LOCATION --query "[?name.value=='$vmFamily'] | [0].currentValue" -o tsv)
quotaLimit=$(az vm list-usage -l $LOCATION --query "[?name.value=='$vmFamily'] | [0].limit" -o tsv)
expr $quotaLimit - $quotaCurrentValue
if [[ $quotaRemaining < ($NODES_COUNT * 2) ]]; 
then 
	1>&2 echo "You don't have enough quota remaining to provision your AKS cluster based on the VM family selected!" 
fi

# Accelerated Networking
# https://docs.microsoft.com/azure/virtual-network/create-vm-accelerated-networking-cli
acceleratedNetworkingEnabled=$(az vm list-skus -l $LOCATION --size $NODE_SIZE --query "[0].capabilities | [?name=='AcceleratedNetworkingEnabled'].value" -o tsv)
if [[ $acceleratedNetworkingEnabled = "False" ]]; 
then 
	1>&2 echo "The Node's size you have selected doesn't support Accelerated Networking!" 
fi