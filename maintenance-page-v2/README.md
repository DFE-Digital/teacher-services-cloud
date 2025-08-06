# Maintenance Page v2 - Centralized Configuration Approach

This improved maintenance page system uses a centralized configuration file and optimized deployment process.

## Key Improvements

1. **Configuration File**: Uses `maint-config.txt` for all maintenance-specific variables
2. **Environment Integration**: Loads service details from existing environment configs (global-config, env-tfvars.json, Makefile)
3. **Tar Archive Distribution**: Creates a lightweight tar archive for deployment without cloning the entire repository
4. **Template Processing**: Dynamically generates HTML with proper variable substitution
5. **Simplified Deployment**: Reduced manual configuration steps

## Directory Structure

```
maintenance-page-v2/
├── README.md
├── config/
│   └── maint-config.txt.example     # Example configuration file
├── scripts/
│   ├── build-maintenance-bundle.sh  # Creates tar archive
│   ├── deploy-maintenance.sh        # Deploys maintenance page
│   ├── process-template.sh          # Process HTML template
│   └── failover.sh                  # Updated failover script
├── templates/
│   └── index.html.template          # HTML template with placeholders
└── manifests/
    └── (kubernetes manifests)
```

## Configuration

### maint-config.txt

Create a `maint-config.txt` file with maintenance-specific variables:

```
MAINTENANCE_MESSAGE="We are currently performing scheduled maintenance"
ESTIMATED_RETURN="<p class='govuk-body'>We expect the service to be available again by <strong>3:00pm on 15 January 2025</strong>.</p>"
STATUS_PAGE="<p class='govuk-body'>For updates, please check our <a href='https://status.service.gov.uk'>status page</a>.</p>"
CONTACT_EMAIL="support@education.gov.uk"
CONTACT_PHONE="0800 123 456"
```

### Service Configuration

Service details are automatically loaded from:
- `global_config/*.sh` - Environment-specific shell configs
- `terraform/application/config/*.tfvars.json` - Terraform variables
- `Makefile` - Service name and repository settings

## Usage

### 1. Create Maintenance Bundle

```bash
# Creates a tar archive with all required files
./scripts/build-maintenance-bundle.sh
```

This creates `maintenance-bundle.tar.gz` containing:
- Processed HTML with variables substituted
- Kubernetes manifests
- Deployment scripts
- Static assets (fonts, images, CSS)

### 2. Deploy to Environment

```bash
# On target environment, download and extract bundle
curl -L https://github.com/org/repo/releases/download/v1.0.0/maintenance-bundle.tar.gz | tar xz

# Deploy maintenance page
./deploy-maintenance.sh production
```

### 3. Update During Incident

To update the maintenance message during an incident:

1. Update `maint-config.txt`
2. Run `./scripts/process-template.sh`
3. Rebuild and redeploy the Docker image

## Benefits

- **Centralized Configuration**: All maintenance variables in one file
- **Reduced Complexity**: No need to edit multiple files
- **Lightweight Distribution**: Small tar archive instead of full repo clone
- **Environment Awareness**: Automatically uses correct service configuration
- **Easy Updates**: Simple process to update messages during incidents