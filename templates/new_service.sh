#!/usr/bin/env bash

set -eu

#SOURCE ALL ENV VARS
set -a
source ./templates/new_service_parameters.env
set +a

DOMAINS_RESOURCE_GROUP_NAME="s189p01-${SERVICE_SHORT}-dom-rg"
FRONT_DOOR_NAME="s189p01-${SERVICE_SHORT}-dom-fd"

echo Copying files to ./new_service ...
rm -rf new_service
cp -r templates/new_service .

#CONFIGURE ENVIRONMENT CONFIG FILES DYNAMICALLY
mkdir -p new_service/global_config
mkdir -p new_service/terraform/application/config
mkdir -p new_service/terraform/domains/environment_domains/config
# mkdir -p new_service/maintenance_page/manifests
# mkdir -p new_service/.github/workflows
# mkdir -p new_service/terraform/application

ENVIRONMENTS_MANDATORY="review production"

options_block=""

for envt in $ENVIRONMENTS_MANDATORY $ENVIRONMENTS; do
  if source "./templates/new_service_config/global_config/${envt}.env"; then
    # runs ONLY if source succeeded
    cp ./templates/new_service_config/global_config/${envt}.env \
      new_service/global_config/${envt}.sh

  #TERRAFORM CONFIG2
  cat <<EOF > new_service/terraform/application/config/$envt.yml
---
EXAMPLE_KEY: example value 1
EOF

  #TERRAFORM CONFIG FILE1
  cp templates/new_service_config/terraform_env_vars/${envt}.tfvars.json \
    new_service/terraform/application/config

else
  echo "undefined environment: $envt"
  exit 1
fi

if [ ${envt} != "review" ]; then
  #DOMAIN ENV CONFIG
  cp -r templates/new_service_config/terraform_env_domain_vars/${envt}.tfvars.json \
    new_service/terraform/domains/environment_domains/config

  #MAINTENANCE PAGE CONFIG
  cp -r templates/new_service_config/maintenance \
    new_service/maintenance_page/manifests/${envt}

  find ./new_service/maintenance_page/manifests/${envt} -type f \
    -exec perl -pi \
      -e "s/#DNS_ZONE_NAME#/${DNS_ZONE_NAME}/g;" \
      -e "s/#ENVIRONMENT#/${ENVIRONMENT}/g;" \
      {} \;

  if [[ "$envt" = "preproduction" || "$envt" = "production" ]]; then
    find ./new_service/maintenance_page/manifests/${envt} -type f \
      -exec perl -pi \
        -e "s/\.test//g;" \
        {} \;
  fi
fi
  options_block+="        - ${envt}"$'\n'

done

for envt in $ENVIRONMENTS; do
  echo >> new_service/Makefile
  cat ./templates/new_service_config/makefile/${envt}.tmp \
    >> new_service/Makefile
  echo >> new_service/Makefile
done

#MAINTENANCE WORKFLOW - UPDATE ENVIRONMENTS
export OPTIONS_BLOCK="$options_block"

awk '
/^        options:[[:space:]]*$/ {
  print
  printf "%s", ENVIRON["OPTIONS_BLOCK"]
  skip=1
  next
}

skip && /^        - / {
  next
}

skip {
  skip=0
}

{ print }
' templates/new_service/.github/workflows/maintenance.yml > tmp.yml \
  && mv tmp.yml new_service/.github/workflows/maintenance.yml

unset OPTIONS_BLOCK

#DOMAINS GLOBAL CONFIG
cat <<EOF > new_service/global_config/domains.sh
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
find ./new_service -type f \
  ! -name '*.png' \
  ! -name '*.woff' \
  ! -name '*.woff2' \
  ! -name '*.ico' \
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
  #DISABLE POSTGRES MODULE CALL
  perl -pi -e '
    if ($. >= 1 && $. <= 15) {
      s/^[^#]/# $&/
    }
  ' new_service/terraform/application/database.tf
else
  #ENABLE POSTGRES MODULE CALL
  perl -pi -e '
    if ($. >= 1 && $. <= 15) {
      s/^# //
    }
  ' new_service/terraform/application/database.tf

  #ADD POSTGRES PROD VALUES
  jq -s '.[0] * .[1]' \
    new_service/terraform/application/config/production.tfvars.json \
    templates/new_service_config/postgres/production-postgres.json \
    > /tmp/input.json \
    && mv /tmp/input.json \
      new_service/terraform/application/config/production.tfvars.json

  #ADD POSTGRES VARIABLES
  cat templates/new_service_config/postgres/postgres-vars.tf \
    >> new_service/terraform/application/variables.tf

  #MOVE DB WORKFLOWS
  cp templates/new_service_config/postgres/workflows/* \
    new_service/.github/workflows
fi

#CONFIGURE REDIS
if [ "${REDIS}" != "true" ]; then
  #DISABLE REDIS MODULE CALL
  perl -pi -e '
    if ($. >= 18 && $. <= 32) {
      s/^[^#]/# $&/
    }
  ' new_service/terraform/application/database.tf
else
  #ENABLE REDIS MODULE CALL
  perl -pi -e '
    if ($. >= 18 && $. <= 32) {
      s/^# //
    }
  ' new_service/terraform/application/database.tf

  #ADD REDIS PROD VALUES
  jq -s '.[0] * .[1]' \
    new_service/terraform/application/config/production.tfvars.json \
    templates/new_service_config/redis/production-redis.json \
    > /tmp/input.json \
    && mv /tmp/input.json \
      new_service/terraform/application/config/production.tfvars.json

  #ADD REDIS VARIABLES
  cat templates/new_service_config/redis/redis-vars.tf \
    >> new_service/terraform/application/variables.tf
fi

#RAILS/DOTNET
if [ "${RAILS_APPLICATION}" = "true" ]; then
  perl -pi -e \
    's/^  is_rails_application *= *.*/  is_rails_application = true/' \
    new_service/terraform/application/application.tf
else
  perl -pi -e \
    's/^  is_rails_application *= *.*/  is_rails_application = false/' \
    new_service/terraform/application/application.tf
fi

awk 'NR == 13 { print }' \
  new_service/terraform/application/application.tf

echo Files are ready in .new_service
