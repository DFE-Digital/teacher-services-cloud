# Scheduled Infrastructure Validation

## Overview

Automated terraform plan checks that detect infrastructure drift between deployed resources and terraform code.

## Components

### GitHub Action: `validate-infra`

Reusable action that runs terraform plan with drift detection and Slack notifications.

**Inputs:**

- `azure-client-id`, `azure-subscription-id`, `azure-tenant-id`: Azure OIDC authentication
- `environment`: Environment to validate (test, platform-test, production)
- `slack-webhook`: Slack webhook URL for notifications

### Scheduled Workflow

`.github/workflows/scheduled-infra-validation.yml`

- **Schedule**: Daily at 2 AM UTC (production)
- **Manual trigger**: Any environment via workflow_dispatch
- **Notifications**: Slack alerts when drift detected

## Setup

### Required Secrets

Configure in GitHub environment settings:

- `AZURE_CLIENT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`: Azure OIDC authentication
- `SLACK_WEBHOOK_ALERTS`: Slack notification webhook

## Usage

### Manual Runs

1. Navigate to Actions → "Scheduled Infrastructure Validation"
2. Click "Run workflow"
3. Select environment and terraform ref
4. Run

### Handling Drift

When drift is detected:

1. Review terraform plan in workflow logs
2. If expected: Apply changes via deployment workflow
3. If unexpected: Investigate and remediate

## Terraform Exit Codes

- `0`: No changes
- `1`: Error
- `2`: Drift detected

## Troubleshooting

- **Authentication errors**: Check Azure OIDC secrets in environment settings
- **Terraform init failures**: Verify backend configuration and storage access
- **Notification failures**: Validate Slack webhook URL
