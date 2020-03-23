#!/bin/bash

# Make sure we have the latest Azure CLI version, for example 2.2.0 is required for Private cluster.
sudo apt-get update
sudo apt-get install azure-cli

az login --service-principal -u $SP_ID -p $SP_SECRET --tenant $SP_TENANT_ID
az account set -s $SUBSCRIPTION_ID

# First checks before going anywhere:
# Zones check
if [[ $ZONES = "true" ]]; then
      azLocations=(centralus eastus eastus2 westus2 francecentral northeurope uksouth westeurope japaneast southeastasia)
      if [[ ! " ${azLocations[@]} " =~ " ${LOCATION} " ]]; then
            1>&2 echo "The location you selected doesn't support Availability Zones!"
      fi
fi
# VM quota check
vmFamily=$(az vm list-skus -l canadacentral --size Standard_DS2_v2 --query [0].family -o tsv)
az vm list-usage --location canadacentral --query "[?name.value=='$vmFamily']"
quotaCurrentValue=$(az vm list-usage --location canadacentral --query "[?name.value=='$vmFamily'] | [0].currentValue" -o tsv)
quotaLimit=$(az vm list-usage --location canadacentral --query "[?name.value=='$vmFamily'] | [0].limit" -o tsv)
expr $quotaLimit - $quotaCurrentValue
if [[ $quotaRemaining = 0 ]]; 
then 
	1>&2 echo "You don't have enough quota remaining to provision your AKS cluster based on the VM family selected!" 
fi

# Define Zones value
zones=""
if [ $ZONES = "true" ]; then
      zones="--zones 1 2 3"
fi
      
# Manage SP and Roles
#aksClientSecret=$(az ad sp create-for-rbac -n $AKS --skip-assignment --query password -o tsv)
aksClientSecret=$SP_SECRET
#aksServicePrincipal=$(az ad sp show --id http://$AKS --query appId -o tsv)
aksServicePrincipal=$SP_ID
      
# Create Resource Group and Lock
az group create -n $RG -l $LOCATION
az group lock create --lock-type CanNotDelete -n CanNotDelete -g $RG

# IP addresses ranges
aksVnetPrefix='192.168.0.0/21' #2048 ips
aksSubnetPrefix='192.168.0.0/23' #512 ips
aksSvcSubnetPrefix='192.168.2.0/24' #256 ips
acrSubnetPrefix='192.168.3.0/27' #32 ips
jumpboxVnetPrefix='10.1.0.0/27' #32 ips
jumpboxSubnetPrefix='10.1.0.0/27' #32 ips

##
# Create the AKS cluster
##
az network vnet create \
  -g $RG \
  -n $AKS \
  --address-prefixes $aksVnetPrefix
aksVnetId=$(az network vnet show \
  -g $RG \
  -n $AKS \
  --query id \
  -o tsv)
aksSubNetId=$(az network vnet subnet create \
  -g $RG \
  -n $AKS-aks \
  --vnet-name $AKS \
  --address-prefixes $aksSubnetPrefix \
  --query id \
  -o tsv)
az network vnet subnet create \
  -g $RG \
  -n $AKS-svc \
  --vnet-name $AKS \
  --address-prefixes $aksSvcSubnetPrefix
#az role assignment create --assignee $aksServicePrincipal --role "Network Contributor" --scope $aksVnetId
k8sVersion=$(az aks get-versions \
  -l $LOCATION \
  --query "orchestrators[?isPreview==null].orchestratorVersion | [-1]" \
  -o tsv)
az aks create \
  -l $LOCATION \
  -n $AKS \
  -g $RG \
  -k $k8sVersion \
  -s $NODE_SIZE \
  -c $NODE_COUNT \
  --no-ssh-key \
  --service-principal $aksServicePrincipal \
  --client-secret $aksClientSecret \
  --enable-private-cluster \
  --vnet-subnet-id $aksSubNetId \
  --network-plugin azure \
  --network-policy calico \
  --load-balancer-sku standard \
  --vm-set-type VirtualMachineScaleSets \
  $zones
# Disable K8S dashboard
az aks disable-addons -a kube-dashboard -n $AKS -g $RG
# Azure Monitor for containers
workspaceResourceId=$(az monitor log-analytics workspace create -g $RG -n $AKS -l $LOCATION --query id -o tsv)
#az role assignment create --assignee $aksServicePrincipal --role Contributor --scope $workspaceResourceId
az aks enable-addons -a monitoring -n $AKS -g $RG --workspace-resource-id $workspaceResourceId

##
# Azure Container Registry (ACR)
##
acrSubNetId=$(az network vnet subnet create \
  -g $RG \
  -n $AKS-acr \
  --vnet-name $AKS \
  --address-prefixes $acrSubnetPrefix \
  --query id \
  -o tsv)
az network vnet subnet update \
  -n $AKS-acr \
  --vnet-name $AKS \
  -g $RG \
  --disable-private-endpoint-network-policies
acrPrivateZone="privatelink.azurecr.io"
az network private-dns zone create \
  -g $RG \
  -n $acrPrivateZone
az network private-dns link vnet create \
  -g $RG \
  -z $acrPrivateZone \
  -n $AKS-acr \
  -v $AKS \
  --registration-enabled false
acrId=$(az acr create \
  -n $AKS \
  -g $RG \
  -l $LOCATION \
  --sku Premium \
  --query id \
  -o tsv)
az aks update \
  -g $RG \
  -n $AKS \
  --attach-acr $acrId
privateEndpointName=$AKS-acr
az network private-endpoint create \
  -n $privateEndpointName \
  -g $RG \
  --vnet-name $AKS \
  --subnet $AKS-acr \
  --private-connection-resource-id $acrId \
  --group-id registry \
  --connection-name $privateEndpointName
networkInterfaceId=$(az network private-endpoint show \
  -n $privateEndpointName \
  -g $RG \
  --query 'networkInterfaces[0].id' \
  --output tsv)
privateIp=$(az resource show \
  --ids $networkInterfaceId \
  --api-version 2019-04-01 --query 'properties.ipConfigurations[1].properties.privateIPAddress' \
  --output tsv)
dataEndpointPrivateIp=$(az resource show \
  --ids $networkInterfaceId \
  --api-version 2019-04-01 \
  --query 'properties.ipConfigurations[0].properties.privateIPAddress' \
  --output tsv)
az network private-dns record-set a create \
  -n $AKS \
  -z $acrPrivateZone \
  -g $RG
az network private-dns record-set a create \
  -n ${AKS}.${LOCATION}.data \
  -z $acrPrivateZone \
  -g $RG
az network private-dns record-set a add-record \
  -n $AKS \
  -z $acrPrivateZone \
  -g $RG \
  -a $privateIp
az network private-dns record-set a add-record \
  -n ${AKS}.${LOCATION}.data \
  -z $acrPrivateZone \
  -g $RG \
  -a $dataEndpointPrivateIp

##
# Azure VM Jumpbox
##
jumpBox=${AKS}jb
az group create \
  -n $jumpBox \
  -l $LOCATION
az network vnet create \
  -n $jumpBox \
  -g $jumpBox \
  --address-prefixes $jumpboxSubnetPrefix \
  --subnet-name $jumpBox \
  --subnet-prefix $jumpboxSubnetPrefix
jumpBoxVnetId=$(az network vnet show \
  -n $jumpBox \
  -g $jumpBox \
  --query id \
  -o tsv)
az vm create \
  -n $jumpBox \
  -g $jumpBox \
  -l $LOCATION
  --image UbuntuLTS \
  --subnet $jumpBox \
  --vnet-name $jumpBox \
  --custom-data cloud-init.sh \
  --ssh-key-values $JUMPBOX_SSH_KEY
az network nsg rule update \
  -n default-allow-ssh \
  --nsg-name ${jumpBox}NSG \
  -g $jumpBox \
  --access Deny
az network vnet peering create \
  -n jumpbox-aks \
  -g $jumpBox \
  --vnet-name $jumpBox \
  --remote-vnet $aksVnetId \
  --allow-vnet-access
az network vnet peering create \
  -n aks-jumpbox \
  -g $RG \
  --vnet-name $AKS \
  --remote-vnet $jumpBoxVnetId \
  --allow-vnet-access
aksNodesResourceGroup=$(az aks show \
  -n $AKS \
  -g $RG \
  --query nodeResourceGroup -o tsv)
aksPrivateDnsZone=$(az network private-dns zone list \
    -g $aksNodesResourceGroup \
    --query [0].name -o tsv)
az network private-dns link vnet create \
  -n $jumpBox \
  -g $aksNodesResourceGroup \
  -v $jumpBoxVnetId \
  -z $aksPrivateDnsZone \
  -e false
