[![Build Status](https://dev.azure.com/mabenoit-ms/MyOwnBacklog/_apis/build/status/myakscluster?branchName=master)](https://dev.azure.com/mabenoit-ms/MyOwnBacklog/_build/latest?definitionId=97?branchName=master)

# myakscluster

To properly setup and secure your AKS cluster, there is a couple of features and components to enable, here is the list:

- [X] Service Principal [#6](https://github.com/mathieu-benoit/myakscluster/issues/6)
- [ ] Azure KeyVault for Azure pipelines [#3](https://github.com/mathieu-benoit/myakscluster/issues/3)
- [X] kured [#13](https://github.com/mathieu-benoit/myakscluster/issues/13)
- [ ] AAD [#10](https://github.com/mathieu-benoit/myakscluster/issues/10)
- [ ] Network Policy [#9](https://github.com/mathieu-benoit/myakscluster/issues/9)
- [ ] (Preview) Pod Security Policy [#20](https://github.com/mathieu-benoit/myakscluster/issues/20)
- [ ] (Preview) Limit Egress Traffic [#16](https://github.com/mathieu-benoit/myakscluster/issues/16)
- [ ] (Preview) IP whitelisting for Kubernetes API [#12](https://github.com/mathieu-benoit/myakscluster/issues/12)
- [ ] (Preview) Azure Policy [#11](https://github.com/mathieu-benoit/myakscluster/issues/11)
- [ ] (Beta) Azure KeyVault Flex Volume [#18](https://github.com/mathieu-benoit/myakscluster/issues/18)
- [ ] (Beta) Pod Identity [#17](https://github.com/mathieu-benoit/myakscluster/issues/17)

# Setup

```
#az account list -o table
#az account set -s <subscriptionId>
subscriptionId=$(az account show --query id -o tsv)
tenantId=$(az account show --query tenantId -o tsv)
spName=<spName>
spSecret=$(az ad sp create-for-rbac -n $spName --role Owner --query password -o tsv)
spId=$(az ad sp show --id http://$spName --query appId -o tsv)
```

# Resources

- [Azure webinar series - Help Deliver Applications Securely with DevSecOps](https://info.microsoft.com/ww-ondemand-help-deliver-applications-securely-with-devsecops-us.html)
- [Enterprise security in the era of containers and Kubernetes](https://mybuild.techcommunity.microsoft.com/sessions/77061)
- [Azure Kubernetes Services: Container Security for a Cloud Native World](https://info.cloudops.com/azure-kubernetes-services-container-security)
- [Tutorial: Bullet-Proof Kubernetes: Learn by Hacking - Luke Bond & Ana-Maria Calin](https://www.youtube.com/watch?v=NEfwUxId1Uk)
