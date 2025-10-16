# Maintenance Page v2 - Configuration File Approach

## Overview

The maintenance page now uses a simple configuration file (`maint-config.txt`) instead of requiring multiple workflow inputs. This simplifies maintenance page customization and deployment.

## Setup

### 1. Create `maint-config.txt` in your service repository

```bash
# Maintenance configuration
SERVICE_PRETTY=Your Service Name
MAINTENANCE_MESSAGE=We are currently performing scheduled maintenance to improve the service
ESTIMATED_RETURN=<p class='govuk-body'>We expect the service to be available again by <strong>3:00pm today</strong>.</p>
STATUS_PAGE=<p class='govuk-body'>For updates, please check our <a href='https://status.education.gov.uk' class='govuk-link'>status page</a>.</p>
CONTACT_EMAIL=support@education.gov.uk
```

**Note**: 
- `ESTIMATED_RETURN` and `STATUS_PAGE` are optional - leave empty to hide these sections
- These fields accept HTML for proper formatting

### 2. Update your workflow

Your maintenance workflow now only needs to reference the config file:

```yaml
- name: Enable or disable maintenance mode
  uses: DFE-Digital/github-actions/maintenance-v2@main
  with:
    # Azure authentication
    azure-client-id: ${{ secrets.AZURE_CLIENT_ID }}
    azure-subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    azure-tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    
    # Core configuration
    environment: ${{ inputs.environment }}
    mode: ${{ inputs.mode }}
    docker-repository: ghcr.io/dfe-digital/your-service-maintenance
    github-token: ${{ secrets.GITHUB_TOKEN }}
    
    # Config file with maintenance settings
    config-file: maint-config.txt
```

## Benefits

1. **Simpler workflow**: No need for multiple input parameters
2. **Easier updates**: Just edit `maint-config.txt` and redeploy
3. **Version controlled**: Config changes are tracked in git
4. **Reusable**: Same config can be used across environments

## Updating During an Incident

To update the maintenance message during an incident:

1. Edit `maint-config.txt` in a new branch
2. Update the `MAINTENANCE_MESSAGE` or `ESTIMATED_RETURN` fields
3. Push the branch to GitHub
4. Re-run the maintenance workflow using the new branch

## Service Information

Service-specific information (like `service-short` for Kubernetes resources) is automatically extracted from your docker repository name. For example:
- `ghcr.io/dfe-digital/teacher-success-maintenance` → `teacher-success`

## Migration from v1

If you're currently using individual workflow inputs, simply:
1. Create a `maint-config.txt` file with your values
2. Update your workflow to use `config-file: maint-config.txt`
3. Remove the individual input parameters