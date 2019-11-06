#!/bin/bash

az --version

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

# Create the AKS cluster
k8sVersion=$(az aks get-versions -l $LOCATION --query 'orchestrators[-1].orchestratorVersion' -o tsv)
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
            --zones 1 2 3
      
# Disable K8S dashboard
az aks disable-addons -a kube-dashboard -n $AKS -g $RG
      
# Azure Monitor for containers
workspaceResourceId=$(az resource create -g $RG --resource-type "Microsoft.OperationalInsights/workspaces" -n $AKS -l $LOCATION -p '{"sku":{"Name":"Standalone"}}' --query id -o tsv)
#az role assignment create --assignee $aksServicePrincipal --role Contributor --scope $workspaceResourceId
az aks enable-addons -a monitoring -n $AKS -g $RG --workspace-resource-id $workspaceResourceId
      
# Get kubeconfig to be able to run following kubectl commands
az aks get-credentials -n $AKS -g $RG --admin
      
# Kured
kuredVersion=1.2.0
kubectl apply -f https://github.com/weaveworks/kured/releases/download/$kuredVersion/kured-$kuredVersion-dockerhub.yaml

# Network Policies
# Example do deny all both ingress and egress on a specific namespace (default here), should be applied to any new namespace.
kubectl apply -f np-deny-all.yml -n default
