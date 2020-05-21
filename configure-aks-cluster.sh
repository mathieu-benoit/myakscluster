# Create secret for kured
KURED_WEB_HOOK_URL=FIXME
kubectl create ns kured
kubectl create secret generic kured \
  -n kured \
  --from-literal=KURED_WEB_HOOK_URL=$KURED_WEB_HOOK_URL
#FIXME: need to then use this secret while deploying the Helm chart by doing something similar to this: `--set extraArgs.slack-hook-url=$KURED_WEB_HOOK_URL`

# Create secret for Azure Pipelines agent
AZP_TOKEN=FIXME
AZP_URL=https://dev.azure.com/FIXME
AZP_AGENT_NAME=$AKS
AZP_POOL=$AKS # + you need to create manually in UI this Pool.

kubectl create ns ado-agent
kubectl create secret generic ado-agent \
  -n ado-agent \
  --from-literal=AZP_URL=$AZP_URL \
  --from-literal=AZP_TOKEN=$AZP_TOKEN \
  --from-literal=AZP_AGENT_NAME=$AZP_AGENT_NAME \
  --from-literal=AZP_POOL=$AZP_POOL

# Create Azure Arc for Kubernetes resources
az connectedk8s connect \
  -n $AKS \
  -g $AKS
az k8sconfiguration create \
  -n cluster-config \
  -c $AKS \
  -g $AKS \
  --operator-instance-name cluster-config \
  --operator-namespace cluster-config \
  -u https://github.com/mathieu-benoit/myakscluster \
  --scope cluster \
  --cluster-type connectedClusters \
  --operator-params '--git-readonly --git-path=cluster-config' \
  --enable-helm-operator true \
  --helm-operator-version `0.6.0` \
  --helm-operator-params '--set helm.versions=v3'