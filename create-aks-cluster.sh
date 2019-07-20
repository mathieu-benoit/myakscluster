#!/bin/bash

az login --service-principal -u $SP_ID -p $SP_SECRET --tenant $SP_TENANT_ID
az account set -s $SUBSCRIPTION_ID
suffix=$(shuf -i 1000-9999 -n 1)
      
# Manage SP and Roles
#aksClientSecret=$(az ad sp create-for-rbac -n $AKS-$suffix --skip-assignment --query password -o tsv)
aksClientSecret=$SP_SECRET
#aksServicePrincipal=$(az ad sp show --id http://$AKS-$suffix --query appId -o tsv)
aksServicePrincipal=$SP_ID
      
# Create Resource Group and Lock
az group create -n $RG-$suffix -l $LOCATION
az group lock create --lock-type CanNotDelete -n CanNotDelete -g $RG-$suffix
      
# Create VNET
aksVnetId=$(az network vnet create -g $RG-$suffix -n $AKS-$suffix --address-prefixes 192.168.0.0/16 --subnet-name $AKS-$suffix --subnet-prefix 192.168.1.0/24 --query id -o tsv)
subNetId=$(az network vnet subnet show -g $RG-$suffix -n $AKS-$suffix --vnet-name $AKS-$suffix --query id -o tsv)
#az role assignment create --assignee $aksServicePrincipal --role "Network Contributor" --scope aksVnetId
      
# Create the AKS cluster
k8sVersion=$(az aks get-versions -l $LOCATION --query 'orchestrators[-1].orchestratorVersion' -o tsv)
az aks create \
            -l $LOCATION \
            -n $AKS-$suffix \
            -g $RG-$suffix \
            -k $k8sVersion \
            -s $NODE_SIZE \
            -c $NODE_COUNT \
            --no-ssh-key \
            --service-principal $aksServicePrincipal \
            --client-secret $aksClientSecret \
            --vnet-subnet-id $subNetId \
            --network-plugin kubenet \
            --network-policy calico
      
# Disable K8S dashboard
az aks disable-addons -a kube-dashboard -n $AKS-$suffix -g $RG-$suffix
      
# Azure Monitor for containers
workspaceResourceId=$(az resource create -g $RG-$suffix --resource-type "Microsoft.OperationalInsights/workspaces" -n $RG-$suffix -l $LOCATION -p '{"sku":{"Name":"Standalone"}}' --query id -o tsv)
# FIXME az role assignment create --assignee $aksServicePrincipal --role Contributor --scope workspaceResourceId
az aks enable-addons -a monitoring -n $AKS-$suffix -g $RG-$suffix --workspace-resource-id $workspaceResourceId
      
# Get kubeconfig to be able to run following kubectl commands
az aks get-credentials -n $AKS-$suffix -g $RG-$suffix
      
# Kured
kuredVersion=1.2.0
kubectl apply -f https://github.com/weaveworks/kured/releases/download/$kuredVersion/kured-$kuredVersion-dockerhub.yaml

# Network Policies
kubectl apply -f np-default-deny-all.yaml
