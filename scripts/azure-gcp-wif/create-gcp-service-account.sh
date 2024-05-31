#!/usr/bin/env sh

# Requires gcloud cli and authentication with gcloud:
# - gcloud init
# - gcloud auth login
PROJECT="rugged-abacus-218110"
ACCOUNT_NAME="register-bigquery-qa"
ACCOUNT_DISPLAY_NAME="register-bigquery-qa"
ACCOUNT_DESCRIPTION="Service account for Register to send events to BigQuery in QA"

# Create service account
gcloud iam service-accounts create $ACCOUNT_NAME \
 --display-name="$ACCOUNT_DISPLAY_NAME" \
 --description="$ACCOUNT_DESCRIPTION" \
 --project=$PROJECT
