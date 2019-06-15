#!/bin/bash

az login --service-principal -u $SP_ID -p $SP_SECRET --tenant $SP_TENANT_ID
az account set -s $SUBSCRIPTION_ID

az lock delete -n CanNotDelete -g $RESOURCE_GROUP
az group delete -n $RESOURCE_GROUP -y --no-wait
#FIXME - az ad sp delete -n $RESOURCE_GROUP
