# Infrastructure Validation

This service includes automated infrastructure validation to detect configuration drift between your terraform code and deployed infrastructure.

## How It Works

The infrastructure validation workflow runs daily to:
1. Execute `terraform plan` with `-detailed-exitcode` flag
2. Detect if infrastructure has drifted from the expected state
3. Send notifications and create issues when drift is detected

## Schedule

- **Automatic**: Runs daily at 3 AM UTC for production environment
- **Manual**: Can be triggered manually for any environment via GitHub Actions

## Configuration

### Enable Notifications

To enable Slack notifications:

1. Set up repository secrets:
   - `AZURE_CREDENTIALS`: Azure service principal credentials
   - `SLACK_WEBHOOK`: Your Slack webhook URL

2. Set up repository variables:
   - `ENABLE_INFRASTRUCTURE_VALIDATION_ALERTS`: Set to `true` to enable Slack alerts

### Customize Schedule

Edit the cron expression in `.github/workflows/infrastructure-validation.yml`:
```yaml
schedule:
  - cron: '0 3 * * *'  # Daily at 3 AM UTC
```

### Slack Channel

The workflow sends notifications to `#<service-short>-alerts`. Ensure this channel exists or modify the workflow to use your preferred channel.

## Handling Drift

When infrastructure drift is detected:

1. **Review the GitHub Issue**: An issue will be created with details about the drift
2. **Check the Workflow Run**: Review the terraform plan output in the workflow logs
3. **Determine the Cause**:
   - Expected changes: Apply them using your deployment workflow
   - Unexpected changes: Investigate who/what made the changes
4. **Resolve the Drift**: Either update the infrastructure or the terraform code
5. **Close the Issue**: Once resolved, close the GitHub issue

## Manual Validation

To manually validate infrastructure:

1. Go to Actions tab in GitHub
2. Select "Infrastructure Validation" workflow
3. Click "Run workflow"
4. Select the environment to validate
5. Click "Run workflow" button

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify `AZURE_CREDENTIALS` secret is correctly configured
   - Check service principal has necessary permissions

2. **Terraform Plan Errors**
   - Ensure terraform configuration is valid
   - Check that the Makefile targets exist for your environment

3. **No Notifications**
   - Verify `ENABLE_INFRASTRUCTURE_VALIDATION_ALERTS` is set to `true`
   - Check `SLACK_WEBHOOK` secret is correctly configured

## Disabling Validation

To temporarily disable scheduled validation:
- Comment out the schedule trigger in the workflow
- Or delete the workflow file entirely

## Exit Codes

The workflow uses terraform's detailed exit codes:
- `0`: No changes detected
- `1`: Error occurred
- `2`: Infrastructure drift detected