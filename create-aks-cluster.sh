#!/bin/bash

# Make sure we have the latest Azure CLI version, for example 2.0.76 is required for Availability Zones.
sudo apt-get update
sudo apt-get install azure-cli

# First checks before going anywhere:
if [[ $ZONES = "true" && $STANDARD_LOAD_BALANCER = "false" ]]; then
      1>&2 echo "Availability Zones should be used with Standard Load Balancer!"
fi 
if [[ $ZONES = "true" ]]; then
      azLocations=(centralus eastus eastus2 westus2 francecentral northeurope uksouth westeurope japaneast southeastasia)
      if [[ ! " ${azLocations[@]} " =~ " ${LOCATION} " ]]; then
            1>&2 echo "The location you selected doesn't support Availability Zones!"
      fi
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
az group lock create --lock-type CanNotDelete -n CanNotDelete -g $RG
      
# Create VNET and Subnets
vnetPrefix='192.168.1.0/24' #256 ips
aksSubnetPrefix='192.168.1.0/25' #128 ips
svcSubnetPrefix='192.168.1.128/25' #128 ips
aksVnetId=$(az network vnet create -g $RG -n $AKS --address-prefixes $vnetPrefix --query id -o tsv)
aksSubNetId=$(az network vnet subnet create -g $RG -n $AKS-aks --vnet-name $AKS --address-prefixes $aksSubnetPrefix --query id -o tsv)
az network vnet subnet create -g $RG -n $AKS-svc --vnet-name $AKS --address-prefixes $svcSubnetPrefix
#az role assignment create --assignee $aksServicePrincipal --role "Network Contributor" --scope $aksVnetId

# Define LB value
loadBalancerSku="basic"
if [ $STANDARD_LOAD_BALANCER = "true" ]; then
      loadBalancerSku="standard"
fi

# Define VM Set Type value
vmSetType="AvailabilitySet"
if [ $VMSS = "true" ]; then
      vmSetType="VirtualMachineScaleSets"
fi

# Define Zones value
zones=""
if [ $ZONES = "true" ]; then
      zones="--zones 1 2 3"
fi

# Create the AKS cluster
k8sVersion=$(az aks get-versions -l $LOCATION --query "orchestrators[?isPreview==null].orchestratorVersion | [-1]" -o tsv)
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
            --vnet-subnet-id $aksSubNetId \
            --network-plugin kubenet \
            --network-policy calico \
            --load-balancer-sku $loadBalancerSku \
            --vm-set-type $vmSetType \
            $zones
      
# Disable K8S dashboard
az aks disable-addons -a kube-dashboard -n $AKS -g $RG
      
# Azure Monitor for containers
workspaceResourceId=$(az monitor log-analytics workspace create -g $RG -n $AKS -l $LOCATION --query id -o tsv)
#az role assignment create --assignee $aksServicePrincipal --role Contributor --scope $workspaceResourceId
az aks enable-addons -a monitoring -n $AKS -g $RG --workspace-resource-id $workspaceResourceId
      
# Azure Container Registry (ACR)
acrId=$(az acr create -n $AKS -g $RG -l $LOCATION --sku Basic --query id -o tsv)
az aks update -g $RG -n $AKS --attach-acr $acrId

# Get kubeconfig to be able to run following kubectl commands
az aks get-credentials -n $AKS -g $RG --admin
      
# Kured
kuredVersion=master-f6e4062 #1.2.0
kubectl create ns kured
helm repo update
helm install kured stable/kured \
            -n kured \
            --set image.tag=$kuredVersion \
            --set nodeSelector."beta\.kubernetes\.io/os"=linux \
            --set extraArgs.start-time=9am \
            --set extraArgs.end-time=5pm \
            --set extraArgs.time-zone=America/Toronto \
            --set extraArgs.reboot-days="mon\,tue\,wed\,thu\,fri" \
            --set tolerations[0].effect=NoSchedule \
            --set tolerations[0].key=node-role.kubernetes.io/master \
            --set tolerations[1].operator=Exists \
            --set tolerations[1].key=CriticalAddonsOnly \
            --set tolerations[2].operator=Exists \
            --set tolerations[2].effect=NoExecute \
            --set tolerations[3].operator=Exists \
            --set tolerations[3].effect=NoSchedule \
            --set extraArgs.slack-hook-url=$KURED_WEB_HOOK_URL

# Network Policies
# Example do deny all both ingress and egress on a specific namespace (default here), should be applied to any new namespace.
kubectl apply -f np-deny-all.yml -n default
