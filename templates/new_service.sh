#!/usr/bin/env bash

set -eu

DOMAINS_RESOURCE_GROUP_NAME="s189p01-${SERVICE_SHORT}-dom-rg"
FRONT_DOOR_NAME="s189p01-${SERVICE_SHORT}-dom-fd"

echo Copying files to ./new_service ...
cp -r templates/new_service .

echo Rendering template...
# Find all text files
# For each file, replace tokens using perl
find ./new_service -type f \
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

echo Files are ready in ./new_service
