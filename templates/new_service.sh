#!/usr/bin/env bash

set -eu

#SOURCE ALL ENV VARS
set -a
source ./templates/new_service_parameters.env
set +a

DOMAINS_RESOURCE_GROUP_NAME="s189p01-${SERVICE_SHORT}-dom-rg"
FRONT_DOOR_NAME="s189p01-${SERVICE_SHORT}-dom-fd"

echo Copying files to ./my_service ...
cp -r templates/new_service templates/my_service 

echo Rendering template...
# Find all text files
# For each file, replace tokens using perl
echo `pwd`
find ./templates/my_service -type f \
  ! -name '*.png' ! -name '*.woff' ! -name '*.woff2' ! -name '*.ico' \
  -exec perl -pi \
    -e "s@#DOCKER_REPOSITORY#@${DOCKER_REPOSITORY}@;" \
    -e "s/#SERVICE_PRETTY#/${SERVICE_PRETTY}/g;" \
    -e "s/#SERVICE_NAME#/${SERVICE_NAME}/g;" \
    -e "s/#SERVICE_SHORT#/${SERVICE_SHORT}/g;" \
    -e "s/#NAMESPACE_PREFIX#/${NAMESPACE_PREFIX}/g;" \
    -e "s/#DNS_ZONE_NAME#/${DNS_ZONE_NAME}/g;" \
    -e "s/#DOMAINS_RESOURCE_GROUP_NAME#/${DOMAINS_RESOURCE_GROUP_NAME}/g;" \
    -e "s/#FRONT_DOOR_NAME#/${FRONT_DOOR_NAME}/g;" \
    {} \;

echo Files are ready in ./my_service



#CONFIGURE ENVIRONMENT CONFIG FILES DYNAMICALLY
for envt in $ENVIRONMENTS; do
  echo "Environment: $envt"

if [[ "$envt" == "sandbox" || "$envt" == "production" ]]; then
  CLUSTER="production"
  AZURE_SUBSCRIPTION=s189-teacher-services-cloud-production
  AZURE_RESOURCE_PREFIX=s189p01
  CONFIG_SHORT=pd
  ENABLE_KV_DIAGNOSTICS=true
  TERRAFORM_MODULES_TAG=stable
elif [[ "$envt" != "development" ]]; then  #qa, review
  CLUSTER="test"
  AZURE_SUBSCRIPTION=s189-teacher-services-cloud-test
  AZURE_RESOURCE_PREFIX=s189t01
  CONFIG_SHORT=$(echo $envt | cut -c1,2)
  KV_PURGE_PROTECTION=false
  TERRAFORM_MODULES_TAG=main
  ENABLE_KV_DIAGNOSTICS=false
elif  [[ "$envt" == "development" ]]; then
  CLUSTER="development"
  AZURE_SUBSCRIPTION=s189-teacher-services-cloud-development
  AZURE_RESOURCE_PREFIX=s189t01
  CONFIG_SHORT=dv
  TERRAFORM_MODULES_TAG=testing
  KV_PURGE_PROTECTION=false
  ENABLE_KV_DIAGNOSTICS=false
fi


cat <<EOF > templates/my_service/terraform/application/config/$envt.tfvars.json
{
    "cluster": "$CLUSTER",
    "namespace": "$NAMESPACE_PREFIX-$CLUSTER",
    "deploy_azure_backing_services": false,
    "enable_postgres_ssl" : false
}
EOF


cat <<EOF > templates/my_service/terraform/application/config/$envt.yml
---
EXAMPLE_KEY: example value 1
EOF

#GLOBAL CONFIG FILE
cat <<EOF > templates/my_service/global_config/$envt.sh
CONFIG=$envt
CONFIG_SHORT=$CONFIG_SHORT
AZURE_SUBSCRIPTION=$AZURE_SUBSCRIPTION
AZURE_RESOURCE_PREFIX=$AZURE_RESOURCE_PREFIX
KV_PURGE_PROTECTION=false
TERRAFORM_MODULES_TAG=$TERRAFORM_MODULES_TAG
ENABLE_KV_DIAGNOSTICS=$ENABLE_KV_DIAGNOSTICS
EOF


done


#CONFIGURE POSTGRES
if [ "${POSTGRES}" != "true" ]; then
  sed -i '1,15 s/^[^#]/# &/' templates/my_service/terraform/application/database.tf
else
  sed -i '1,15 s/^# //' templates/my_service/terraform/application/database.tf
fi

#CONFIGURE REDIS
if [ "${REDIS}" != "true" ]; then
  sed -i '18,32 s/^[^#]/# &/' templates/my_service/terraform/application/database.tf
else
  sed -i '18,32 s/^# //' templates/my_service/terraform/application/database.tf
fi

#RAILS/DOTNET
if [ "${RAILS_APPLICATION}" = "true" ]; then
  sed -i 's/^  is_rails_application *= *.*/  is_rails_application = true/' templates/my_service/terraform/application/application.tf
else
  sed -i 's/^  is_rails_application *= *.*/  is_rails_application = false/' templates/my_service/terraform/application/application.tf
fi

sed -n '13p' templates/my_service/terraform/application/application.tf