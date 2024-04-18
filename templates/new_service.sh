#!/usr/bin/env bash

set -eu

bsdsed(){
    sed -i '' -e "$1" "$2"
}
gnused(){
    sed -i -e "$1" "$2"
}

case $(uname) in
  Darwin)
    SED_CMD=bsdsed
    ;;
  Linux)
    SED_CMD=gnused
    ;;
  *)
    echo Unknown system: $(uname)
    ;;
esac

cp -r templates/new_service .

$SED_CMD "s/#SERVICE_NAME#/${SERVICE_NAME}/" new_service/Makefile
$SED_CMD "s/#SERVICE_SHORT#/${SERVICE_SHORT}/" new_service/Makefile
$SED_CMD "s@#DOCKER_REPOSITORY#@${DOCKER_REPOSITORY}@" new_service/Makefile
$SED_CMD "s/#NAMESPACE_PREFIX#/${NAMESPACE_PREFIX}/" new_service/terraform/application/config/development.tfvars.json
$SED_CMD "s/#NAMESPACE_PREFIX#/${NAMESPACE_PREFIX}/" new_service/terraform/application/config/production.tfvars.json
$SED_CMD "s/#DNS_ZONE_NAME#/${DNS_ZONE_NAME}/" new_service/terraform/domains/infrastructure/config/zones.tfvars.json

DOMAINS_RESOURCE_GROUP_NAME=s189p01-${SERVICE_SHORT}-domains-rg
$SED_CMD "s/#DOMAINS_RESOURCE_GROUP_NAME#/${DOMAINS_RESOURCE_GROUP_NAME}/" new_service/terraform/domains/infrastructure/config/zones.tfvars.json

FRONT_DOOR_NAME="s189p01-${SERVICE_SHORT}-domains-fd"
$SED_CMD "s/#FRONT_DOOR_NAME#/${FRONT_DOOR_NAME}/" new_service/terraform/domains/infrastructure/config/zones.tfvars.json

$SED_CMD "s/#DNS_ZONE_NAME#/${DNS_ZONE_NAME}/" new_service/terraform/domains/environment_domains/config/development.tfvars.json
$SED_CMD "s/#DNS_ZONE_NAME#/${DNS_ZONE_NAME}/" new_service/terraform/domains/environment_domains/config/production.tfvars.json

FRONT_DOOR_NAME=s189p01-${SERVICE_SHORT}-domains-fd
$SED_CMD "s/#FRONT_DOOR_NAME#/${FRONT_DOOR_NAME}/" new_service/terraform/domains/environment_domains/config/development.tfvars.json
$SED_CMD "s/#FRONT_DOOR_NAME#/${FRONT_DOOR_NAME}/" new_service/terraform/domains/environment_domains/config/production.tfvars.json

$SED_CMD "s/#DOMAINS_RESOURCE_GROUP_NAME#/${DOMAINS_RESOURCE_GROUP_NAME}/" new_service/terraform/domains/environment_domains/config/development.tfvars.json
$SED_CMD "s/#DOMAINS_RESOURCE_GROUP_NAME#/${DOMAINS_RESOURCE_GROUP_NAME}/" new_service/terraform/domains/environment_domains/config/production.tfvars.json

$SED_CMD "s/#SERVICE_NAME#/${SERVICE_NAME}/" new_service/terraform/domains/environment_domains/config/development.tfvars.json
$SED_CMD "s/#SERVICE_NAME#/${SERVICE_NAME}/" new_service/terraform/domains/environment_domains/config/production.tfvars.json

$SED_CMD "s/#DNS_ZONE_NAME#/${DNS_ZONE_NAME}/" new_service/terraform/application/config/production.tfvars.json
