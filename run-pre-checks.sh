#!/bin/bash

az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.KubernetesConfiguration

# Zones - Location
if [[ $ZONES = "true" ]]; then
      azLocations=(centralus eastus eastus2 westus2 francecentral northeurope uksouth westeurope japaneast southeastasia)
      if [[ ! " ${azLocations[@]} " =~ " ${LOCATION} " ]]; then
            1>&2 echo "The location you selected doesn't support Availability Zones!"
      fi
fi

# Zones - VM SKU
if [[ $ZONES = "true" ]]; then
      zonesEnabled=$(az vm list-skus -l $LOCATION --size $NODE_SIZE --query "[0].locationInfo[0].zoneDetails")
      echo $zonesEnabled
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
	1>&2 echo "The Node's size you have selected doesn't support Accelerated Networking which could degrade network performance!" 
fi

# Premium Disk
# https://docs.microsoft.com/azure/virtual-machines/linux/disks-types#premium-ssd
premiumDiskEnabled=$(az vm list-skus -l $LOCATION --size $NODE_SIZE --query "[0].capabilities | [?name=='PremiumIO'].value" -o tsv)
if [[ $premiumDiskEnabled = "False" ]]; 
then 
	1>&2 echo "The Node's size you have selected doesn't support Premium Disk which could degrade IO performance!" 
fi

# Commands below in progress... WIP/FIXME
# IOPS (VM vs Disk)
# Fam. - Size - IOPS
# P10  - 128  - 500
# P15  - 256  - 1100
# P20  - 512  - 2300
# P30  - 1024 - 5000
# P40  - 2048 - 7500
az vm list-skus -l $LOCATION --size $NODE_SIZE --query "[0].capabilities | [?name=='UncachedDiskIOPS'].value" -o tsv
az vm list-skus -l $LOCATION -r disks --query "[?name=='Premium_LRS']" -o table