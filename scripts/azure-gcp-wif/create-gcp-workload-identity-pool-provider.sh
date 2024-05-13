#!/usr/bin/env bash

# Requires gcloud cli and authentication with gcloud:
# - gcloud init
# - gcloud auth login
PROJECT="rugged-abacus-218110"

# Create workload identity pool
# NOTE: must be "global" region (Can't use for example "europe-west2")
gcloud iam workload-identity-pools providers create-oidc azure-cip-oidc-provider \
 --location="global" \
 --workload-identity-pool="azure-cip-identity-pool" \
 --issuer-uri="https://login.microsoftonline.com/9c7d9dd3-840c-4b3f-818e-552865082e16/v2.0" \
 --allowed-audiences="fb60f99c-7a34-4190-8149-302f77469936" \
 --attribute-mapping="google.subject=assertion.sub" \
 --project=$PROJECT
