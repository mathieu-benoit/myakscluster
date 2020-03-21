#!/bin/bash

ssh -i $JUMPBOX_SSH_KEY vsts@JUMPBOX_IP_ADDRESS

ls -la

az login --service-principal -u $SP_ID -p $SP_SECRET --tenant $SP_TENANT_ID
az account set -s $SUBSCRIPTION_ID
