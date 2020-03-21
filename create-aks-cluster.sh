#!/bin/bash

# Make sure we have the latest Azure CLI version, for example 2.2.0 is required for Private cluster.
#sudo apt-get update
#sudo apt-get install azure-cli

# First checks before going anywhere:
if [[ $ZONES = "true" ]]; then
      azLocations=(centralus eastus eastus2 westus2 francecentral northeurope uksouth westeurope japaneast southeastasia)
      if [[ ! " ${azLocations[@]} " =~ " ${LOCATION} " ]]; then
            1>&2 echo "The location you selected doesn't support Availability Zones!"
      fi
fi

# Define Zones value
zones=""
if [ $ZONES = "true" ]; then
      zones="--zones 1 2 3"
fi

az login --service-principal -u $SP_ID -p $SP_SECRET --tenant $SP_TENANT_ID
az account set -s $SUBSCRIPTION_ID
      
# Manage SP and Roles
#aksClientSecret=$(az ad sp create-for-rbac -n $AKS --skip-assignment --query password -o tsv)
aksClientSecret=$SP_SECRET
#aksServicePrincipal=$(az ad sp show --id http://$AKS --query appId -o tsv)
aksServicePrincipal=$SP_ID
      
# Create Resource Group and Lock
az group create -n $RG -l $LOCATION
#az group lock create --lock-type CanNotDelete -n CanNotDelete -g $RG

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
#k8sVersion=$(az aks get-versions \
#  -l $LOCATION \
#  --query "orchestrators[?isPreview==null].orchestratorVersion | [-1]" \
#  -o tsv)
#az aks create \
#            -l $LOCATION \
#            -n $AKS \
#            -g $RG \
#            -k $k8sVersion \
#            -s $NODE_SIZE \
#            -c $NODE_COUNT \
#            --no-ssh-key \
#            --service-principal $aksServicePrincipal \
#            --client-secret $aksClientSecret \
#            --enable-private-cluster \
#            --vnet-subnet-id $aksSubNetId \
#            --network-plugin azure \
#            --network-policy calico \
#            --load-balancer-sku standard \
#            --vm-set-type VirtualMachineScaleSets \
#            $zones
# Disable K8S dashboard
#az aks disable-addons -a kube-dashboard -n $AKS -g $RG
# Azure Monitor for containers
#workspaceResourceId=$(az monitor log-analytics workspace create -g $RG -n $AKS -l $LOCATION --query id -o tsv)
#az role assignment create --assignee $aksServicePrincipal --role Contributor --scope $workspaceResourceId
#az aks enable-addons -a monitoring -n $AKS -g $RG --workspace-resource-id $workspaceResourceId

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
az network private-endpoint create \
  -n myPrivateEndpoint \
  -g $RG \
  --vnet-name $AKS \
  --subnet $subnetName \
  --private-connection-resource-id $acrId \
  --group-ids registry \
  --connection-name myConnection
networkInterfaceID=$(az network private-endpoint show \
  --name myPrivateEndpoint \
  --resource-group $resourceGroup \
  --query 'networkInterfaces[0].id' \
  --output tsv)
privateIP=$(az resource show \
  --ids $networkInterfaceID \
  --api-version 2019-04-01 --query 'properties.ipConfigurations[1].properties.privateIPAddress' \
  --output tsv)
dataEndpointPrivateIP=$(az resource show \
  --ids $networkInterfaceID \
  --api-version 2019-04-01 \
  --query 'properties.ipConfigurations[0].properties.privateIPAddress' \
  --output tsv)
az network private-dns record-set a create \
  --name $registryName \
  --zone-name privatelink.azurecr.io \
  --resource-group $resourceGroup
az network private-dns record-set a create \
  --name ${registryName}.${registryLocation}.data \
  --zone-name privatelink.azurecr.io \
  --resource-group $resourceGroup
az network private-dns record-set a add-record \
  --record-set-name $registryName \
  --zone-name privatelink.azurecr.io \
  --resource-group $resourceGroup \
  --ipv4-address $privateIP
az network private-dns record-set a add-record \
  --record-set-name ${registryName}.${registryLocation}.data \
  --zone-name privatelink.azurecr.io \
  --resource-group $resourceGroup \
  --ipv4-address $dataEndpointPrivateIP

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
echo JUMPBOX: $JUMPBOX_SSH_KEY
echo $jumpBoxVnetId
az vm create \
  -n $jumpBox \
  -g $jumpBox \
  --image UbuntuLTS \
  --subnet $jumpBox \
  --vnet-name $jumpBox \
  --custom-data cloud-init.txt \
  --ssh-key-values $JUMPBOX_SSH_KEY
#az network nsg rule update \
#  -n default-allow-ssh \
#  --nsg-name ${jumpBox}NSG \
#  -g $jumpBox \
#  --access Deny
az network vnet peering create \
  -n jumpbox-aks \
  -g $jumpBox \
  --vnet-name $jumpBox \
  --remote-vnet $aksVnetId \
  --allow-vnet-access
az network vnet peering create \
  -n aks-jumpbox \
  -g $AKS \
  --vnet-name $AKS \
  --remote-vnet $jumpBoxVnetId \
  --allow-vnet-access
#aksNodesResourceGroup=$(az aks show \
#  -n $aks \
#  -g $aks \
#  --query nodeResourceGroup -o tsv) 
#aksPrivateDnsZone=$(az network private-dns zone list \
#    --resource-group $aksNodesResourceGroup \
#    --query [0].name -o tsv)
#az network private-dns link vnet create \
#  --name $name \
#  --resource-group $aksNodesResourceGroup \
#  --virtual-network $vNet1Id \
#  --zone-name $aksPrivateDnsZone \
#  --registration-enabled false
