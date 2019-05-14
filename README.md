# myakscluster

TODO:

- Azure KeyVault
- Azure Pipelines

# Create Resource Group and AKS

```
location=eastus
rg=<rg-name>
aks=<aks-name>
sku=Standard_B2s
k8sVersion=$(az aks get-versions -l $location --query 'orchestrators[-1].orchestratorVersion' -o tsv)
az group create -n $rg -l $location
az aks create -l $location -n $aks -g $rg --generate-ssh-keys -k $k8sVersion -s $(nodeSize) -c 1
```

# Create ACR

```
acr=<acr-name>
az acr create -n $acr -g $rg -l $location --sku Basic

# Grant the AKS-generated service principal pull access to our ACR, the AKS cluster will be able to pull images from ACR
CLIENT_ID=$(az aks show -g $rg -n $aks --query "servicePrincipalProfile.clientId" -o tsv)
ACR_ID=$(az acr show -n $acr -g $rg --query "id" -o tsv)
az role assignment create --assignee $CLIENT_ID --role acrpull --scope $ACR_ID
```

# Configure AKS

```
az aks get-credentials -n $aks -g $rg

# Setup tiller for Helm, we will discuss about this tool later
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
```
