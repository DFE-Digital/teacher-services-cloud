# Scheduled Infrastructure Validation

## Overview

The scheduled infrastructure validation system runs automated terraform plan checks against deployed infrastructure to detect configuration drift. This helps ensure that the actual infrastructure state matches the expected state defined in terraform code.

## Components

### 1. GitHub Action: `validate-infra`

Location: [DFE-Digital/github-actions/validate-infra](https://github.com/DFE-Digital/github-actions/tree/main/validate-infra)

A reusable GitHub Action that:
- Runs `terraform plan` with `-detailed-exitcode` flag
- Detects infrastructure drift (exit code 2)
- Sends Slack notifications on drift detection
- Returns drift status for further processing

#### Inputs

- `azure_credentials`: Azure service principal credentials (required)
- `environment`: Environment to validate (test, platform-test, production)
- `terraform_main_ref`: Git ref to use for terraform code (default: main)
- `slack_webhook`: Slack webhook URL for notifications
- `slack_channel`: Slack channel for notifications (default: #infrastructure-alerts)

#### Outputs

- `drift_detected`: Whether drift was detected (true/false/error)
- `plan_output`: The terraform plan output
- `changes_summary`: Summary of detected changes

### 2. Scheduled Workflow

Location: `.github/workflows/scheduled-infra-validation.yml`

Runs daily validation of production infrastructure:
- **Schedule**: Daily at 2 AM UTC
- **Manual trigger**: Supports manual runs for any environment
- **Drift handling**:
  - Sends Slack notification
  - Creates/updates GitHub issue
  - Provides actionable information

### 3. Service Template

Location: `.github/workflows/service-infra-validation-template.yml`

Template workflow for individual services to implement their own validation.

## Setup

### 1. Update Makefile

Add the `set-detailed-exitcode` target and update terraform plan commands:

```makefile
set-detailed-exitcode:
	$(eval DETAILED_EXITCODE=-detailed-exitcode)

terraform-aks-cluster-plan: terraform-aks-cluster-init
	terraform -chdir=cluster/terraform_aks_cluster plan -var-file config/${CONFIG}.tfvars.json ${DETAILED_EXITCODE}

terraform-kubernetes-plan: terraform-kubernetes-init
	terraform -chdir=cluster/terraform_kubernetes plan -var-file config/${CONFIG}.tfvars.json ${DETAILED_EXITCODE}
```

### 2. Configure Secrets

Required GitHub secrets:
- `AZURE_CREDENTIALS`: Service principal for Azure authentication
- `SLACK_WEBHOOK`: Webhook URL for Slack notifications

### 3. Customize Schedule

Edit the cron expression in the workflow to adjust timing:
```yaml
schedule:
  - cron: '0 2 * * *'  # Daily at 2 AM UTC
```

## Usage

### Manual Validation

Trigger manual validation via GitHub Actions UI:
1. Go to Actions tab
2. Select "Scheduled Infrastructure Validation"
3. Click "Run workflow"
4. Select environment and terraform ref
5. Click "Run workflow"

### Automated Validation

The workflow automatically runs daily for production. When drift is detected:

1. **Slack Notification** is sent to configured channel
2. **GitHub Issue** is created or updated with:
   - Summary of changes
   - Link to workflow run
   - Action items

### Handling Drift

When drift is detected:

1. **Review the plan output** in the workflow run
2. **Determine if changes are expected**:
   - Expected: Apply changes using deployment workflow
   - Unexpected: Investigate cause of drift
3. **Resolve the drift** by either:
   - Applying terraform changes
   - Updating infrastructure to match code
   - Fixing unauthorized changes
4. **Close the GitHub issue** once resolved

## Exit Codes

Terraform plan with `-detailed-exitcode` returns:
- `0`: No changes (infrastructure matches configuration)
- `1`: Error occurred
- `2`: Changes detected (drift present)

## Customization for Services

Services can adopt this pattern by:

1. **Option 1**: Use the central action
   ```yaml
   uses: DFE-Digital/github-actions/validate-infra@main
   ```

2. **Option 2**: Copy and customize the template
   - Copy `service-infra-validation-template.yml`
   - Update service-specific values
   - Adjust schedule to avoid conflicts

## Best Practices

1. **Schedule Timing**: Stagger validation times across services to avoid resource contention
2. **Environment Selection**: Focus scheduled runs on production, use manual triggers for other environments
3. **Notification Channels**: Use service-specific Slack channels for better visibility
4. **Issue Management**: Regularly review and close drift issues
5. **SHA Pinning**: Services can override terraform ref for testing specific versions

## Monitoring

Track validation effectiveness through:
- GitHub Actions run history
- Slack notification frequency
- Open drift issues count
- Time to resolution metrics

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify `AZURE_CREDENTIALS` secret is valid
   - Check service principal permissions

2. **Terraform Init Failures**
   - Ensure backend configuration is correct
   - Verify storage account access

3. **False Positives**
   - Review plan output for timestamp-based changes
   - Consider using `ignore_changes` for known dynamic values

4. **Notification Failures**
   - Verify Slack webhook URL is valid
   - Check Slack channel permissions

## Future Enhancements

Potential improvements to consider:
- Multiple environment validation in single run
- Configurable drift tolerance levels
- Integration with other notification systems
- Automated drift remediation for safe changes
- Drift metrics dashboard
- Cost impact analysis of detected changes