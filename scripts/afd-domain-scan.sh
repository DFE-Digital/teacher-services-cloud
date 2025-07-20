#!/bin/bash
set -e

TODAY=$(date -Idate)
TZ=Europe/London

################################################################################
# Author:
#   Ash Davies <@DrizzlyOwl>
# Version:
#   0.1.0
# Description:
#   Search an Azure Subscription for Azure Front Door Custom Domains that are
#   secured using Azure Managed TLS Certificates. If the Custom Domain is in a
#   'pending' state then a new domain validation token is requested and the DNS
#   TXT record set is updated with the new token.
# Usage:
#   ./afd-domain-scan.sh [-s <subscription name>]
#      -s       <subscription name>      (optional) Azure Subscription
#
#   If you do not specify the subscription name, the script will prompt you to
#   select one based on the current logged in Azure user.
################################################################################

while getopts "s:" opt; do
  case $opt in
    s)
      AZ_SUBSCRIPTION_SCOPE=$OPTARG
      ;;
    *)
      ;;
  esac
done

# If a subscription scope has not been defined on the command line using '-e'
# then prompt the user to select a subscription from the account
if [ -z "${AZ_SUBSCRIPTION_SCOPE}" ]; then
  AZ_SUBSCRIPTIONS=$(
    az account list --output json |
    jq -c '[.[] | select(.state == "Enabled").name]'
  )

  echo "🌐 Choose an option"
  AZ_SUBSCRIPTIONS="$(echo "$AZ_SUBSCRIPTIONS" | jq -r '. | join(",")')"

  # Read from the list of available subscriptions and prompt them to the user
  # with a numeric index for each one
  if [ -n "$AZ_SUBSCRIPTIONS" ]; then
    IFS=',' read -r -a array <<< "$AZ_SUBSCRIPTIONS"

    echo
    cat -n < <(printf "%s\n" "${array[@]}")
    echo

    n=""

    # Ask the user to select one of the indexes
    while true; do
        read -rp 'Select subscription to query: ' n
        # If $n is an integer between one and $count...
        if [ "$n" -eq "$n" ] && [ "$n" -gt 0 ]; then
          break
        fi
    done

    i=$((n-1)) # Arrays are zero-indexed
    AZ_SUBSCRIPTION_SCOPE="${array[$i]}"
  fi
fi

echo "🎯 Using subscription $AZ_SUBSCRIPTION_SCOPE"
echo

echo "🔎 Looking for Azure Front Door CDNs..."

# Find all Azure Front Doors within the specified subscription
AFD_LIST=$(
  az afd profile list \
    --only-show-errors \
    --subscription "$AZ_SUBSCRIPTION_SCOPE" |
  jq -rc '.[] | { "name": .name, "resourceGroup": .resourceGroup }'
)

for AZURE_FRONT_DOOR in $AFD_LIST; do
  RESOURCE_GROUP=$(echo "$AZURE_FRONT_DOOR" | jq -rc '.resourceGroup')
  AFD_NAME=$(echo "$AZURE_FRONT_DOOR" | jq -rc '.name')

  echo "  🚪 Azure Front Door $AFD_NAME in Resource Group $RESOURCE_GROUP..."

  # Grab all the custom domains attached to the Azure Front Door
  ALL_CUSTOM_DOMAINS=$(
    az afd custom-domain list \
      --profile-name "$AFD_NAME" \
      --output json \
      --only-show-errors \
      --subscription "$AZ_SUBSCRIPTION_SCOPE" \
      --resource-group "$RESOURCE_GROUP"
  )

  # Create a new list of domains where TLS certificate type is Azure 'managed'
  DOMAINS=$(
    echo "$ALL_CUSTOM_DOMAINS" |
    jq -rc '.[] | select(.tlsSettings.certificateType = "ManagedCertificate") | {
      "domain": .hostName,
      "id": .id,
      "validationProperties": .validationProperties,
      "state": .domainValidationState,
      "azureDnsZone": .azureDnsZone
    }'
  )

  if [ -z "$DOMAINS" ]; then
    echo "     ✅ No domains were found that need revalidating"
  else
    for DOMAIN in $(echo "$DOMAINS" | jq -c); do
      DOMAIN_NAME=$(echo "$DOMAIN" | jq -rc '.domain')
      RESOURCE_ID=$(echo "$DOMAIN" | jq -rc '.id')
      STATE=$(echo "$DOMAIN" | jq -rc '.state')
      DOMAIN_VALIDATION_EXPIRY=$(echo "$DOMAIN" | jq -rc '.validationProperties.expirationDate')
      DOMAIN_TOKEN=$(echo "$DOMAIN" | jq -rc '.validationProperties.validationToken')
      DOMAIN_DNS_ZONE_ID=$(echo "$DOMAIN" | jq -rc '.azureDnsZone.id')

      echo "     🌐 $DOMAIN_NAME = $STATE"

      if [ "$STATE" == "Pending" ] || [ "$STATE" == "PendingRevalidation" ]; then
        # Check expiry of existing token
        DOMAIN_VALIDATION_EXPIRY_DATE=${DOMAIN_VALIDATION_EXPIRY:0:10}
        DOMAIN_VALIDATION_EXPIRY_DATE_COMP=${DOMAIN_VALIDATION_EXPIRY_DATE//-/}
        TODAY_COMP=${TODAY//-/}

        echo "           Checking whether we can use the current validation token..."
        echo "           ⏲️  Token $DOMAIN_TOKEN expires on $DOMAIN_VALIDATION_EXPIRY_DATE"

        if [[ "$DOMAIN_VALIDATION_EXPIRY_DATE_COMP" < "$TODAY_COMP" ]]; then
          echo "           Existing validation token has expired."

          # Regenerate token
          echo "           Please wait whilst a new validation token is generated..."
          az afd custom-domain regenerate-validation-token \
            --ids "$RESOURCE_ID" \
            --output json

          # Refresh the $DOMAIN resource which will have a new token
          DOMAIN=$(
            az afd custom-domain show \
              --ids "$RESOURCE_ID" \
              --output json \
              --only-show-errors
          )

          STATE=$(echo "$DOMAIN" | jq -rc '.domainValidationState')
        else
          echo "           Existing validation token is still valid."
        fi
      fi

      # Second check of State due to potential resource refreshed
      if [ "$STATE" == "Pending" ]; then
        # Grab the new or existing token
        DOMAIN_TOKEN=$(echo "$DOMAIN" | jq -rc '.validationProperties.validationToken')

        # Locate the DNS zone that holds the TXT Record Set
        DOMAIN_DNS_ZONE=$(
          az network dns zone show \
            --ids "$DOMAIN_DNS_ZONE_ID" \
            --output json \
            --only-show-errors |
          jq -rc '{ "name": .name, "etag": .etag }'
        )

        # Handle subdomains by extracting the primary DNS Zone name
        # from the domain name to determine the validation record name
        DOMAIN_DNS_ZONE_NAME=$(echo "$DOMAIN_DNS_ZONE" | jq -rc '.name')
        RECORD_SET_NAME_TMP=${DOMAIN_NAME//${DOMAIN_DNS_ZONE_NAME}/}
        RECORD_SET_NAME_TMP="_dnsauth.${RECORD_SET_NAME_TMP}"
        RECORD_SET_NAME=${RECORD_SET_NAME_TMP/%./}

        # Get the existing record to determine if we need to do anything
        RECORD_SET_CURRENT_TOKEN=$(
          az network dns record-set txt show \
            --zone-name "$DOMAIN_DNS_ZONE_NAME" \
            --name "$RECORD_SET_NAME" \
            --output json \
            --subscription "$AZ_SUBSCRIPTION_SCOPE"  \
            --resource-group "$RESOURCE_GROUP" |
          jq -rc '.TXTRecords[0].value[0]'
        )

        echo "           Checking DNS Record for validation token"
        echo "           - Old value: $RECORD_SET_CURRENT_TOKEN"
        echo "           + New value: $DOMAIN_TOKEN"
        echo

        if [ "$RECORD_SET_CURRENT_TOKEN" != "$DOMAIN_TOKEN" ]; then
          echo "           Your DNS TXT Record will be automatically updated."

          # Update the DNS record with the validation token
          RECORD_SET_STATE=$(
            az network dns record-set txt update \
              --zone-name "$DOMAIN_DNS_ZONE_NAME" \
              --name "$RECORD_SET_NAME" \
              --set "txtRecords[0].value[0]=$DOMAIN_TOKEN" \
              --output json \
              --subscription "$AZ_SUBSCRIPTION_SCOPE"  \
              --resource-group "$RESOURCE_GROUP" |
            jq -rc '.provisioningState'
          )

          echo
          echo "           ✅  DNS Record update: $RECORD_SET_STATE"
        else
          echo "           ✅  Your DNS Record has already been updated. Nothing to do."
        fi
      fi
    done
  fi
  echo
done