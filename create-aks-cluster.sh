az login --service-principal -u $spId -p $spSecret --tenant $spTenantId
az account set -s $subscriptionId
suffix=$(shuf -i 1000-9999 -n 1)
az group create -n $rg-$suffix -l $location
#az group lock create --lock-type CanNotDelete -n CanNotDelete -g $rg-$suffix
#aksClientSecret=$(az ad sp create-for-rbac -n $aks-$suffix --skip-assignment --query password -o tsv)
aksClientSecret=$spSecret
#aksServicePrincipal=$(az ad sp show --id http://$aks-$suffix --query appId -o tsv)
aksServicePrincipal=$spId
#az role assignment create --assignee $aksServicePrincipal --role Contributor --scope /subscriptions/$subscriptionId/resourceGroups/$rg-$suffix
k8sVersion=$(az aks get-versions -l $location --query 'orchestrators[-1].orchestratorVersion' -o tsv)
az aks create \
      -l $location \
      -n $aks-$suffix \
      -g $rg-$suffix \
      -k $k8sVersion \
      -s $nodeSize \
      -c $nodeCount \
      --no-ssh-key \
      --service-principal $aksServicePrincipal \
      --client-secret $aksClientSecret
az aks get-credentials -n $aks-$suffix -g $rg-$suffix
# Azure Monitor for containers
az aks enable-addons -a monitoring -n $aks-$suffix -g $rg-$suffix
# Kured
kuredVersion=1.2.0
kubectl apply -f https://github.com/weaveworks/kured/releases/download/$kuredVersion/kured-$kuredVersion-dockerhub.yaml
