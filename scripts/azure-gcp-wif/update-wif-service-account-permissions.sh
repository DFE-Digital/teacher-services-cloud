#!/usr/bin/env sh

# Requires gcloud cli and authentication with gcloud:
# - gcloud init
# - gcloud auth login
PROJECT="rugged-abacus-218110"
PROJECT_NUMBER="712009772377"
ACCOUNT_NAME="register-bigquery-qa"
SERVICE_ACCOUNT_EMAIL="${ACCOUNT_NAME}@${PROJECT}.iam.gserviceaccount.com"

AZURE_MANAGED_IDENTITY_OBJECT_ID="<azure-managed-identity-principal-object-id>"
POOL_ID="azure-cip-identity-pool"

PRINCIPLE="principal://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/subject/$AZURE_MANAGED_IDENTITY_OBJECT_ID"

# Assign role: Workload Identity User to the service account
gcloud projects add-iam-policy-binding $PROJECT \
 --member="serviceAccount:${ACCOUNT_NAME}@${PROJECT}.iam.gserviceaccount.com" \
 --role="roles/iam.workloadIdentityUser"

# Grant role: Workload Identity User to service account for workload Identity pool
gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT_EMAIL \
 --project=$PROJECT \
 --role="roles/iam.workloadIdentityUser" \
 --member=$PRINCIPLE
