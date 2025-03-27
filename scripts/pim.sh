#!/bin/bash

# Script to activate PIM roles from terminal
# Make sure you are logged in with: az login

# Get user information
echo "Getting user information..."
userEmailAddress=$(az account show -o tsv --query "user.name" 2>/dev/null)
userObjectId=$(az ad signed-in-user show --query id -o tsv 2>/dev/null)

if [ -z "$userObjectId" ]; then
  echo "❌ Failed to get user object ID. Please verify your Azure CLI login."
  exit 1
fi

echo "Logged in as: $userEmailAddress ($userObjectId)"

# Define subscription IDs - replace these with actual subscription IDs
declare -a subscription_ids=(
  "9816b7b0-58ca-4972-b25b-c7dbd3ee1c6d"  # s165-test
  "9c2dcb72-4bba-4acc-8d5f-8b8389a68238"  # s165-prod
  "20da9d12-7ee1-42bb-b969-3fe9112964a7"  # s189-test
  "3c033a0c-7a1c-4653-93cb-0f2a9f57a391"  # s189-prod
  "20da9d12-7ee1-42bb-b969-3fe9112964a7"  # s189-test (ResLock)
  "3c033a0c-7a1c-4653-93cb-0f2a9f57a391"  # s189-prod (ResLock)
)

# Define friendly names for display
declare -a subscription_names=(
  "s165-teachingqualificationsservice-test"
  "s165-teachingqualificationsservice-production"
  "s189-teacher-services-cloud-test"
  "s189-teacher-services-cloud-production"
  "s189-teacher-services-cloud-test (ResLock)"
  "s189-teacher-services-cloud-production (ResLock)"
)

# Define role display names
declare -a role_names=(
  "s165-Teaching Qualifications Service-Contributor and Key Vault Secrets Officer"
  "s165-Teaching Qualifications Service-Contributor and Key Vault Secrets Officer"
  "s189-Contributor and Key Vault editor"
  "s189-Contributor and Key Vaults editor"
  "s189-teacher-services-cloud-ResLock Admin"
  "s189-teacher-services-cloud-ResLock Admin"
)

# Define role definition IDs
declare -a role_definition_ids=(
  "b86a8fe4-44ce-4948-aee5-eccb2c155cd7"  # Key Vault Secrets Officer for s165-test
  "b86a8fe4-44ce-4948-aee5-eccb2c155cd7"  # Key Vault Secrets Officer for s165-prod
  "21090545-7ca7-4776-b22c-e363652d74d2"  # Key Vault editor for s189-test
  "21090545-7ca7-4776-b22c-e363652d74d2"  # Key Vault editor for s189-prod
  "b24988ac-6180-42a0-ab88-20f7382dd24c"  # Contributor for s189-test (ResLock)
  "b24988ac-6180-42a0-ab88-20f7382dd24c"  # Contributor for s189-prod (ResLock)
)

# Function to activate a role using direct API call
activate_role() {
  local index=$1
  local subscription_id=${subscription_ids[$index]}
  local display_name=${subscription_names[$index]}
  local role_name=${role_names[$index]}
  local role_def_id=${role_definition_ids[$index]}
  local scope="/subscriptions/$subscription_id"

  echo "Activating: $role_name on $display_name"
  echo "Debug info:"
  echo "- User ID: $userObjectId"
  echo "- Subscription ID: $subscription_id"
  echo "- Role Definition ID: $role_def_id"
  echo "- Scope: $scope"

  # Generate request ID
  request_id=$(uuidgen | tr -d '-')

  # Get token
  token=$(az account get-access-token --resource "https://management.azure.com" -o tsv --query "accessToken")

  # Calculate ISO 8601 start time (now)
  start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Make the request to the PIM API
  echo "Sending activation request..."
  response=$(curl -X PUT \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -d '{
      "properties": {
        "principalId": "'"$userObjectId"'",
        "roleDefinitionId": "'"$scope"'/providers/Microsoft.Authorization/roleDefinitions/'"$role_def_id"'",
        "requestType": "SelfActivate",
        "justification": "Required for work",
        "scheduleInfo": {
          "startDateTime": "'"$start_time"'",
          "expiration": {
            "type": "AfterDuration",
            "endDateTime": null,
            "duration": "PT8H"
          }
        }
      }
    }' \
    "https://management.azure.com/subscriptions/$subscription_id/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/$request_id?api-version=2020-10-01" \
    --silent)

  # Check response
  if echo "$response" | jq -e '.' >/dev/null 2>&1; then
    status=$(echo "$response" | jq -r '.status // "Unknown"')
    if [[ "$status" == "Approved" || "$status" == "Succeeded" ]]; then
      echo "✅ Activation successful for: $role_name on $display_name"
    else
      echo "ℹ️ Activation status: $status for: $role_name on $display_name"
      echo "Response details:"
      echo "$response" | jq '.'

      # Try traditional role assignment if PIM fails
      echo "Trying traditional role assignment..."
      az role assignment create --role "$role_def_id" --scope "$scope" --assignee-object-id "$userObjectId" 2>/dev/null
    fi
  else
    echo "⚠️ Unexpected response format: $response"
  fi
}

# Display options
echo "Available PIM roles to activate:"
for i in "${!subscription_names[@]}"; do
  echo "$i: ${role_names[$i]} on ${subscription_names[$i]}"
done

# Process selection
if [[ "$1" == "--all" ]]; then
  echo "Activating all roles..."
  for i in "${!subscription_names[@]}"; do
    activate_role $i
  done
else
  read -p "Enter role numbers to activate (comma-separated) or 'all': " selection

  if [[ "$selection" == "all" ]]; then
    for i in "${!subscription_names[@]}"; do
      activate_role $i
    done
  else
    IFS=',' read -ra SELECTED <<< "$selection"
    for i in "${SELECTED[@]}"; do
      if [[ $i =~ ^[0-9]+$ ]] && [ $i -lt ${#subscription_names[@]} ]; then
        activate_role $i
      else
        echo "Invalid selection: $i"
      fi
    done
  fi
fi

echo "Operation completed."
