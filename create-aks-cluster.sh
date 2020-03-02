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
vnetPrefix='192.168.1.0/23' #512 ips
aksSubnetPrefix='192.168.1.0/25' #128 ips
svcSubnetPrefix='192.168.1.128/25' #128 ips
aksVnetId=$(az network vnet create -g $RG -n $AKS --address-prefixes $vnetPrefix --query id -o tsv)
#az role assignment create --assignee $aksServicePrincipal --role "Network Contributor" --scope $aksVnetId
aksSubNetId=$(az network vnet subnet create -g $RG -n $AKS-aks --vnet-name $AKS --address-prefixes $aksSubnetPrefix --query id -o tsv)
az network vnet subnet create -g $RG -n $AKS-svc --vnet-name $AKS --address-prefixes $svcSubnetPrefix
fwSubnetPrefix='192.168.2.0/25' #128 ips
fwSubnetName="AzureFirewallSubnet" # DO NOT CHANGE FWSUBNET_NAME - This is currently a requirement for Azure Firewall.
az network vnet subnet create -g $RG --vnet-name $AKS -n $fwSubnetName --address-prefixes $fwSubnetPrefix

# Create the Azure Firewall
az extension add --name azure-firewall
az network public-ip create -g $RG -n $AKS-fw-ip -l $LOCATION --sku "Standard"
az network firewall create -g $RG -n $AKS -l $LOCATION
az network firewall ip-config create -g $RG -f $AKS -n $AKS-fw-ip --public-ip-address $AKS-fw-ip --vnet-name $AKS # it's taking a long time...
fwPublicIp=$(az network public-ip show -g $RG -n $AKS-fw-ip --query "ipAddress" -o tsv)
fwPrivateIp=$(az network firewall show -g $RG -n $AKS --query "ipConfigurations[0].privateIpAddress" -o tsv)
# Create UDR & Routing Table for Azure Firewall
az network route-table create -g $RG --name $FWROUTE_TABLE_NAME
az network route-table route create -g $RG --name $FWROUTE_NAME --route-table-name $FWROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $fwPrivateIp --subscription $SUBID
# Create the Outbound Network Rule from Worker Nodes to Control Plane
az network firewall network-rule create -g $RG -f $AKS --collection-name 'aksfwnr1' -n 'ssh' --protocols 'TCP' --source-addresses '*' --destination-addresses '*' --destination-ports 9000 443 --action allow --priority 100
az network firewall network-rule create -g $RG -f $AKS --collection-name 'aksfwnr2' -n 'dns' --protocols 'UDP' --source-addresses '*' --destination-addresses '*' --destination-ports 53 --action allow --priority 200
az network firewall network-rule create -g $RG -f $AKS --collection-name 'aksfwnr3' -n 'gitssh' --protocols 'TCP' --source-addresses '*' --destination-addresses '*' --destination-ports 22 --action allow --priority 300
az network firewall network-rule create -g $RG -f $AKS --collection-name 'aksfwnr4' -n 'fileshare' --protocols 'TCP' --source-addresses '*' --destination-addresses '*' --destination-ports 445 --action allow --priority 400
az network firewall application-rule create -g $RG -f $AKS \
    --collection-name 'AKS_Global_Required' \
    --action allow \
    --priority 100 \
    -n 'required' \
    --source-addresses '*' \
    --protocols 'http=80' 'https=443' \
    --target-fqdns \
        #'aksrepos.azurecr.io' \
        #'*blob.core.windows.net' \
        'mcr.microsoft.com' \
        #'*cdn.mscr.io' \
        '*.data.mcr.microsoft.com' \
        'management.azure.com' \
        'login.microsoftonline.com' \
        'ntp.ubuntu.com' \
        'packages.microsoft.com' \
        'acs-mirror.azureedge.net'
az network firewall application-rule create -g $RG -f $AKS \
    --collection-name 'AKS_Cloud_Specific_Required' \
    --action allow \
    --priority 200 \
    -n 'required' \
    --source-addresses '*' \
    --protocols 'http=80' 'https=443' \
    --target-fqdns \
        '*.hcp.$LOCATION.azmk8s.io' \
        '*.tun.$LOCATION.azmk8s.io'
az network firewall application-rule create -g $RG -f $AKS \
    --collection-name 'AKS_Update_Required' \
    --action allow \
    --priority 300 \
    -n 'ubuntu' \
    --source-addresses '*' \
    --protocols 'http=80' 'https=443' \
    --target-fqdns \
        'security.ubuntu.com' \
        'azure.archive.ubuntu.com' \
        'changelogs.ubuntu.com'
az network firewall application-rule create -g $RG -f $AKS \
    --collection-name 'AKS_Azure_Monitor_Required' \
    --action allow \
    --priority 500 \
    -n 'azure_monitor' \
    --source-addresses '*' \
    --protocols 'https=443' \
    --target-fqdns \
        'dc.services.visualstudio.com' \
        '*.ods.opinsights.azure.com' \
        '*.oms.opinsights.azure.com' \
        '*.microsoftonline.com' \
        '*.monitoring.azure.com'
az network firewall application-rule create -g $RG -f $AKS \
    --collection-name 'AKS_For_Public_Container_Registries_Required' \
    --action allow \
    --priority 600 \
    -n 'registries' \
    --source-addresses '*' \
    --protocols 'https=443' \
    --target-fqdns \
        #'*auth.docker.io' \
        #'*cloudflare.docker.io' \
        #'*cloudflare.docker.com' \
        #'*registry-1.docker.io' \
        #'apt.dockerproject.org' \
        #'gcr.io' \
        #'storage.googleapis.com' \
        #'*.quay.io' \
        #'quay.io' \
        #'*.cloudfront.net' \
        '*.azurecr.io' #\
        #'*.gk.azmk8s.io' \
        #'raw.githubusercontent.com' \
        #'gov-prod-policy-data.trafficmanager.net' \
        #'api.snapcraft.io'
# Associate AKS Subnet to FW
az network vnet subnet update -g $RG --route-table $FWROUTE_TABLE_NAME --ids $aksSubNetId

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
kuredVersion=1.3.0
kubectl create ns kured
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
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
