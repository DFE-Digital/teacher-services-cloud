#!/usr/bin/env sh

# Requires gcloud cli and authentication with gcloud:
# - gcloud init
# - gcloud auth login
PROJECT="rugged-abacus-218110"

# Create workload identity pool
# NOTE: must be "global" region (Can't use for example "europe-west2")
gcloud iam workload-identity-pools create azure-cip-identity-pool \
 --location="global" \
 --description="Azure CIP -> GCP Workload identity pool" \
 --display-name="azure-cip-identity-pool" \
 --project=$PROJECT
