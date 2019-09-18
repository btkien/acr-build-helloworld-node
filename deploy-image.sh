#!/bin/bash

#!/bin/bash

echo "Enter the resource group name:"
read RES_GROUP
echo "Enter the location (i.e southeastasia)"
read location
az group create --name $RES_GROUP --location $location

if [[ $? = 0 ]]; then
  echo "You just create resource group successfull"
else
  echo "You just create resource group fail,please try again"
fi
az group list | grep $RES_GROUP

echo "Enter name of Container Registry:"
read ACR_NAME
echo "Enter your plan SKU (Basic,Standard,Premium):"
read sku
az acr create --resource-group "$RES_GROUP" --name $ACR_NAME --sku $sku
if [[ $? = 0 ]]; then
  echo "You just create ACR successfull"
else
  echo "You just create ACR fail,please try again"
fi

echo "Do you wanna keep building image:(yes-no)"
read userinput
if [[ $userinput == 'yes' ]]; then
   az acr build --registry $ACR_NAME --image helloacrtasks:v1 .
else
   echo "Bye"
   exit 0
fi

if [[ $? = 0 ]]; then
  echo "You just build image to $ACR_NAME.azurerc.io successfull"
else
  echo "You just build fail,please try again"
fi

#Create Key-Vault

AKV_NAME=$ACR_NAME-vault
echo "Begining Create Key-Vault"
az keyvault create --resource-group $RES_GROUP --name $AKV_NAME
if [[ $? = 0 ]]; then
  echo "You just create key-vault $AKV_NAME  successfull"
else
  echo "You just build fail,please try again"
fi

# Create service principal, store its password in AKV (the registry *password*)
echo "Create A new Service principal"
az keyvault secret set \
  --vault-name $AKV_NAME \
  --name $ACR_NAME-pull-pwd \
  --value $(az ad sp create-for-rbac \
                --name $ACR_NAME-pull \
                --scopes $(az acr show --name $ACR_NAME --query id --output tsv) \
                --role acrpull \
                --query password \
                --output tsv)

echo "Store Service Principal ID in AKV"
# Store service principal ID in AKV (the registry *username*)
az keyvault secret set \
    --vault-name $AKV_NAME \
    --name $ACR_NAME-pull-usr \
    --value $(az ad sp show --id http://$ACR_NAME-pull --query appId --output tsv)


#Deploy a container to ACR

echo "Now We deploy a container to Aure Container Registry"
echo "This step will take a moment.Please wait"

az container create \
    --resource-group $RES_GROUP \
    --name acr-tasks \
    --image $ACR_NAME.azurecr.io/helloacrtasks:v1 \
    --registry-login-server $ACR_NAME.azurecr.io \
    --registry-username $(az keyvault secret show --vault-name $AKV_NAME --name $ACR_NAME-pull-usr --query value -o tsv) \
    --registry-password $(az keyvault secret show --vault-name $AKV_NAME --name $ACR_NAME-pull-pwd --query value -o tsv) \
    --dns-name-label acr-tasks-$ACR_NAME \
    --query "{FQDN:ipAddress.fqdn}" \
    --output table

echo "Do you wanna attach to running container:(yes-no)"
read userinput
if [[ $userinput == 'yes' ]]; then
   az container attach --resource-group $RES_GROUP --name acr-tasks
else
   echo "Bye"
   exit 0
fi




