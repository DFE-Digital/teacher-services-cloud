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

#CONFIGURE ENVIRONMENT CONFIG FILES DYNAMICALLY
mkdir -p templates/my_service/global_config
mkdir -p templates/my_service/terraform/application/config

ENVIRONMENTS_MANDATORY="development review production"

options_block=""

for envt in $ENVIRONMENTS_MANDATORY $ENVIRONMENTS; do
  if source "./templates/new_service_config/global_config/${envt}.env"; then
    # runs ONLY if source succeeded
    source ./templates/new_service_config/global_config/${envt}.env

#GLOBAL CONFIG FILE
cat <<EOF > templates/my_service/global_config/$envt.sh
CONFIG=$envt
ENVIRONMENT=$ENVIRONMENT
CONFIG_SHORT=$CONFIG_SHORT
AZURE_SUBSCRIPTION=$AZURE_SUBSCRIPTION
AZURE_RESOURCE_PREFIX=$AZURE_RESOURCE_PREFIX
KV_PURGE_PROTECTION=false
TERRAFORM_MODULES_TAG=$TERRAFORM_MODULES_TAG
ENABLE_KV_DIAGNOSTICS=$ENABLE_KV_DIAGNOSTICS
EOF

  #TERRAFORM CONFIG2
  cat <<EOF > templates/my_service/terraform/application/config/$envt.yml
  ---
  EXAMPLE_KEY: example value 1
EOF

  #TERRAFORM CONFIG FILE1
  cp templates/new_service_config/terraform_env_vars/${envt}.tfvars.json templates/my_service/terraform/application/config

else
  echo "undefined environment: $envt"
  exit 1
fi

  #MAINTENANCE PAGE CONFIG
  cp -r templates/new_service_config/maintenance templates/my_service/maintenance_page/manifests/${envt}

  find ./templates/my_service/maintenance_page/manifests/${envt} -type f \
    -exec perl -pi \
      -e "s/#DNS_ZONE_NAME#/${DNS_ZONE_NAME}/g;" \
      -e "s/#ENVIRONMENT#/${ENVIRONMENT}/g;" \
      {} \;

  if [[ "$envt" = "sandbox" || "$envt" = "production" ]]; then
    find ./templates/my_service/maintenance_page/manifests/${envt} -type f \
      -exec perl -pi \
        -e "s/\.test//g;" \
        {} \;
  fi

    options_block+="        - ${envt}"$'\n'

done

#MAINTENANCE WORKFLOW - UPDATE ENVIRONMENTS
  awk -v new_opts="$options_block" '
  /options:/ {
    print
    print new_opts
    skip=1
    next
  }
  skip && /^[[:space:]]*-/ { next }  # skip old list items
  { print }
  ' templates/new_service/.github/workflows/maintenance.yml > tmp.yml && mv tmp.yml templates/my_service/.github/workflows/maintenance.yml

#DOMAINS GLOBAL CONFIG
cat <<EOF > templates/my_service/global_config/domains.sh
{
      AZURE_SUBSCRIPTION=s189-teacher-services-cloud-production
      AZURE_RESOURCE_PREFIX=s189p01
      CONFIG_SHORT=dom
      DISABLE_KEYVAULTS=true
      TERRAFORM_MODULES_TAG=stable
}
EOF

echo Rendering template...
# Find all text files
# For each file, replace tokens using perl

find ./templates/my_service -type f \
  ! -name '*.png' ! -name '*.woff' ! -name '*.woff2' ! -name '*.ico' \
  -exec perl -pi \
    -e "s@#DOCKER_REPOSITORY#@${DOCKER_REPOSITORY}@;" \
    -e "s/#SERVICE_PRETTY#/${SERVICE_PRETTY}/g;" \
    -e "s/#SERVICE_NAME#/${SERVICE_NAME}/g;" \
    -e "s/#SERVICE_SHORT#/${SERVICE_SHORT}/g;" \
    -e "s/#NAMESPACE_PREFIX#/${NAMESPACE_PREFIX}/g;" \
    -e "s/#DNS_ZONE_NAME#/${DNS_ZONE_NAME}/g;" \
    -e "s/#ENVIRONMENT#/${ENVIRONMENT}/g;" \
    -e "s/#DOMAINS_RESOURCE_GROUP_NAME#/${DOMAINS_RESOURCE_GROUP_NAME}/g;" \
    -e "s/#FRONT_DOOR_NAME#/${FRONT_DOOR_NAME}/g;" \
    {} \;


#CONFIGURE POSTGRES
if [ "${POSTGRES}" != "true" ]; then
  sed -i '1,15 s/^[^#]/# &/' templates/my_service/terraform/application/database.tf
else
  #ENABLE POSTGRES MODULE CALL
  sed -i '1,15 s/^# //' templates/my_service/terraform/application/database.tf
  #ADD POSTGRES PROD VALUES
  jq -s '.[0] * .[1]' templates/my_service/terraform/application/config/production.tfvars.json templates/new_service_config/postgres/production-postgres.json > /tmp/input.json && mv /tmp/input.json templates/my_service/terraform/application/config/production.tfvars.json
  #ADD POSTGRES VARIABLES
  cat templates/new_service_config/postgres/postgres-vars.tf >> templates/my_service/terraform/application/variables.tf
  #MOVE DB WORKFLOWS
  cp templates/new_service_config/postgres/workflows/* templates/my_service/.github/workflows
fi

#CONFIGURE REDIS
if [ "${REDIS}" != "true" ]; then
  #ENABLE REDIS MODULE CALL
  sed -i '18,32 s/^[^#]/# &/' templates/my_service/terraform/application/database.tf
else
  #ENABLE REDIS MODULE CALL
  sed -i '18,32 s/^# //' templates/my_service/terraform/application/database.tf
  #ADD REDIS PROD VALUES
  jq -s '.[0] * .[1]' templates/my_service/terraform/application/config/production.tfvars.json templates/new_service_config/redis/production-redis.json > /tmp/input.json && mv /tmp/input.json templates/my_service/terraform/application/config/production.tfvars.json
  #ADD REDIS VARIABLES
  cat templates/new_service_config/redis/redis-vars.tf >> templates/my_service/terraform/application/variables.tf
fi


#RAILS/DOTNET
if [ "${RAILS_APPLICATION}" = "true" ]; then
  sed -i 's/^  is_rails_application *= *.*/  is_rails_application = true/' templates/my_service/terraform/application/application.tf
else
  sed -i 's/^  is_rails_application *= *.*/  is_rails_application = false/' templates/my_service/terraform/application/application.tf
fi

sed -n '13p' templates/my_service/terraform/application/application.tf


echo Files are ready in ./my_service