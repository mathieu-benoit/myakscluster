#!/bin/bash

az login --service-principal -u $SP_ID -p $SP_SECRET --tenant $SP_TENANT_ID
az account set -s $SUBSCRIPTION_ID
suffix=$(shuf -i 1000-9999 -n 1)
      
# Manage SP and Roles
#aksClientSecret=$(az ad sp create-for-rbac -n $AKS --skip-assignment --query password -o tsv)
aksClientSecret=$SP_SECRET
#aksServicePrincipal=$(az ad sp show --id http://$AKS --query appId -o tsv)
aksServicePrincipal=$SP_ID
      
# Create Resource Group and Lock
az group create -n $RG -l $LOCATION
az group lock create --lock-type CanNotDelete -n CanNotDelete -g $RG
      
# Create VNET
aksVnetId=$(az network vnet create -g $RG -n $AKS --address-prefixes 192.168.0.0/16 --subnet-name $AKS --subnet-prefix 192.168.1.0/24 --query id -o tsv)
subNetId=$(az network vnet subnet show -g $RG -n $AKS --vnet-name $AKS --query id -o tsv)
#az role assignment create --assignee $aksServicePrincipal --role "Network Contributor" --scope aksVnetId
      
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
            --vnet-subnet-id $subNetId
      
# Disable K8S dashboard
az aks disable-addons -a kube-dashboard -n $AKS -g $RG
      
# Azure Monitor for containers
workspaceResourceId=$(az resource create -g $RG --resource-type "Microsoft.OperationalInsights/workspaces" -n $AKS -l $LOCATION -p '{"sku":{"Name":"Standalone"}}' --query id -o tsv)
# FIXME az role assignment create --assignee $aksServicePrincipal --role Contributor --scope workspaceResourceId
az aks enable-addons -a monitoring -n $AKS -g $RG --workspace-resource-id $workspaceResourceId
      
# Get kubeconfig to be able to run following kubectl commands
az aks get-credentials -n $AKS -g $RG
      
# Kured
kuredVersion=1.2.0
kubectl apply -f https://github.com/weaveworks/kured/releases/download/$kuredVersion/kured-$kuredVersion-dockerhub.yaml
