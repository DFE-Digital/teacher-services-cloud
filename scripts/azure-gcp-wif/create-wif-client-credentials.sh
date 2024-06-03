#!/usr/bin/env sh

# Requires gcloud cli and authentication with gcloud:
# - gcloud init
# - gcloud auth login
PROJECT="rugged-abacus-218110"
PROJECT_NUMBER="712009772377"
ACCOUNT_NAME="register-bigquery-qa"
SERVICE_ACCOUNT_EMAIL="${ACCOUNT_NAME}@${PROJECT}.iam.gserviceaccount.com"
AZURE_TOKEN_URL="https://login.microsoftonline.com/9c7d9dd3-840c-4b3f-818e-552865082e16/oauth2/v2.0/token"

POOL_ID="azure-cip-identity-pool"
PROVIDER_ID="azure-cip-oidc-provider"
PROVIDER="projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID"
OUTPUT_FILE_DIR="$HOME/Downloads"

# Download client credentials config file
gcloud iam workload-identity-pools create-cred-config $PROVIDER \
  --service-account=$SERVICE_ACCOUNT_EMAIL \
  --service-account-token-lifetime-seconds=3600 \
  --credential-source-url=$AZURE_TOKEN_URL \
  --output-file=$OUTPUT_FILE_DIR/gcpClientConfig-$ACCOUNT_NAME.json
