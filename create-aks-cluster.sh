#!/bin/bash

# Define Zones value
zones=""
if [ $ZONES = "true" ]; then
      zones="--zones 1 2 3"
fi
      
# Create Resource Group and Lock
az group create \
  -n $AKS \
  -l $LOCATION
az group lock create \
  --lock-type CanNotDelete \
  -n CanNotDelete \
  -g $AKS

# IP addresses ranges
dockerBridgeAddress='172.17.0.1/27' #32 ips
serviceCidr='192.168.0.0/24' #256 ips
dnsServiceIp='192.168.0.10'
aksVnetPrefix='100.64.0.0/21' #2048 ips
aksSubnetPrefix='100.64.0.0/23' #512 ips
aksSvcSubnetPrefix='100.64.2.0/24' #256 ips
acrSubnetPrefix='100.64.3.0/27' #32 ips
jumpboxVnetPrefix='10.1.0.0/26' #64 ips
jumpboxSubnetPrefix='10.1.0.0/27' #32 ips
bastionSubnetPrefix='10.1.0.32/27' #32 ips

##
# Create the AKS cluster
##
az network vnet create \
  -g $AKS \
  -n $AKS \
  --address-prefixes $aksVnetPrefix
aksVnetId=$(az network vnet show \
  -g $AKS \
  -n $AKS \
  --query id \
  -o tsv)
aksSubNetId=$(az network vnet subnet create \
  -g $AKS \
  -n $AKS-aks \
  --vnet-name $AKS \
  --address-prefixes $aksSubnetPrefix \
  --query id \
  -o tsv)
az network vnet subnet create \
  -g $AKS \
  -n $AKS-svc \
  --vnet-name $AKS \
  --address-prefixes $aksSvcSubnetPrefix
az aks create \
  -l $LOCATION \
  -n $AKS \
  -g $AKS \
  -k $K8S_VERSION \
  -s $NODE_SIZE \
  -c $NODES_COUNT \
  --uptime-sla \
  --dns-name-prefix $AKS \
  --nodepool-name system \
  --no-ssh-key \
  --enable-managed-identity \
  --skip-subnet-role-assignment \
  --enable-private-cluster \
  --vnet-subnet-id $aksSubNetId \
  --network-plugin azure \
  --network-policy calico \
  --load-balancer-sku standard \
  --vm-set-type VirtualMachineScaleSets \
  --docker-bridge-address $dockerBridgeAddress \
  --service-cidr $serviceCidr \
  --dns-service-ip $dnsServiceIp \
  $zones
# Linux User Nodepool
az aks nodepool add \
  -g $AKS \
  --cluster-name $AKS \
  -n userlinux \
  --os-type Linux \
  --mode User \
  --labels kubernetes.azure.com/mode=user \
  -s $NODE_SIZE \
  -c $NODES_COUNT \
  -k $K8S_VERSION \
  $zones
  #--vnet-subnet-id # still in preview and calico is not supported
# Disable K8S dashboard
az aks disable-addons \
  -a kube-dashboard \
  -n $AKS \
  -g $AKS
# Azure Monitor for containers
workspaceResourceId=$(az monitor log-analytics workspace create \
  -g $AKS \
  -n $AKS \
  -l $LOCATION \
  --query id \
  -o tsv)
az aks enable-addons \
  -a monitoring \
  -n $AKS \
  -g $AKS \
  --workspace-resource-id $workspaceResourceId

##
# Azure Container Registry (ACR)
##
acrSubNetId=$(az network vnet subnet create \
  -g $AKS \
  -n $AKS-acr \
  --vnet-name $AKS \
  --address-prefixes $acrSubnetPrefix \
  --query id \
  -o tsv)
az network vnet subnet update \
  -n $AKS-acr \
  --vnet-name $AKS \
  -g $AKS \
  --disable-private-endpoint-network-policies
acrPrivateZone="privatelink.azurecr.io"
az network private-dns zone create \
  -g $AKS \
  -n $acrPrivateZone
az network private-dns link vnet create \
  -g $AKS \
  -z $acrPrivateZone \
  -n $AKS-acr \
  -v $AKS \
  --registration-enabled false
acrId=$(az acr create \
  -n $AKS \
  -g $AKS \
  -l $LOCATION \
  --sku Premium \
  --query id \
  -o tsv)
az acr update \
  -n $AKS \
  -g $AKS \
  --default-action Deny
az aks update \
  -g $AKS \
  -n $AKS \
  --attach-acr $acrId
privateEndpointName=$AKS-acr
az network private-endpoint create \
  -n $privateEndpointName \
  -g $AKS \
  --vnet-name $AKS \
  --subnet $AKS-acr \
  --private-connection-resource-id $acrId \
  --group-id registry \
  --connection-name $privateEndpointName
networkInterfaceId=$(az network private-endpoint show \
  -n $privateEndpointName \
  -g $AKS \
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
  -g $AKS
az network private-dns record-set a create \
  -n ${AKS}.${LOCATION}.data \
  -z $acrPrivateZone \
  -g $AKS
az network private-dns record-set a add-record \
  -n $AKS \
  -z $acrPrivateZone \
  -g $AKS \
  -a $privateIp
az network private-dns record-set a add-record \
  -n ${AKS}.${LOCATION}.data \
  -z $acrPrivateZone \
  -g $AKS \
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
  -l $LOCATION \
  --image UbuntuLTS \
  --size Standard_B2s \
  --subnet $jumpBox \
  --vnet-name $jumpBox \
  --custom-data cloud-init.sh \
  --ssh-key-values $JUMPBOX_SSH_KEY
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
aksNodesResourceGroup=$(az aks show \
  -n $AKS \
  -g $AKS \
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

# Azure Bastion
bastionSubNetId=$(az network vnet subnet create \
  -g $jumpBox \
  -n "AzureBastionSubnet" \
  --vnet-name $jumpBox \
  --address-prefixes $bastionSubnetPrefix \
  --query id \
  -o tsv)
bastionPublicIp=$(az network public-ip create \
  -g $jumpBox \
  -n ${jumpBox}-bastion \
  --allocation-method Static \
  --sku Standard \
  --query publicIp.ipAddress \
  -o tsv)
az network bastion create \
  -n $jumpBox \
  --public-ip-address $bastionPublicIp \
  -g $jumpBox \
  --vnet-name $jumpBox \
  -l $LOCATION