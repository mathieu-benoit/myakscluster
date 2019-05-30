az login --service-principal -u $SP_ID -p $SP_SECRET --tenant $SP_TENANT_ID
az account set -s $SUBSCRIPTION_ID
suffix=$(shuf -i 1000-9999 -n 1)
az group create -n $RG-$suffix -l $LOCATION
#az group lock create --lock-type CanNotDelete -n CanNotDelete -g $RG-$suffix
aksClientSecret=$(az ad sp create-for-rbac -n $AKS-$suffix --skip-assignment --query password -o tsv)
#aksClientSecret=$SP_SECRET
aksServicePrincipal=$(az ad sp show --id http://$AKS-$suffix --query appId -o tsv)
#aksServicePrincipal=$SP_ID
az role assignment create --assignee $aksServicePrincipal --role Contributor --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG-$suffix
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
      --client-secret $aksClientSecret
az aks get-credentials -n $AKS-$suffix -g $RG-$suffix
# Azure Monitor for containers
az aks enable-addons -a monitoring -n $AKS-$suffix -g $RG-$suffix
# Kured
kuredVersion=1.2.0
kubectl apply -f https://github.com/weaveworks/kured/releases/download/$kuredVersion/kured-$kuredVersion-dockerhub.yaml
