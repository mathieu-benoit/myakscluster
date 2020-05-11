#!/bin/bash

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