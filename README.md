# myakscluster

To properly setup and secure your AKS cluster, there is a couple of feature and component to enable, here is the list:


- Azure KeyVault
- Azure Pipelines
- (Preview) Limit Egress Traffic [#16](https://github.com/mathieu-benoit/myakscluster/issues/16)
- (Preview) Use IP whitelisting for the Kubernetes API [#12](https://github.com/mathieu-benoit/myakscluster/issues/12)

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

# Resources

- [Azure webinar series - Help Deliver Applications Securely with DevSecOps](https://info.microsoft.com/ww-ondemand-help-deliver-applications-securely-with-devsecops-us.html)
- [Enterprise security in the era of containers and Kubernetes](https://mybuild.techcommunity.microsoft.com/sessions/77061)
- [Azure Kubernetes Services: Container Security for a Cloud Native World](https://info.cloudops.com/azure-kubernetes-services-container-security)
