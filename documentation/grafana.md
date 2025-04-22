# Grafana Monitoring

## Overview
Grafana provides visualization and monitoring capabilities for our infrastructure and applications. Our Grafana instance is deployed in Kubernetes and secured with Azure AD authentication.

## Authentication Architecture
- Grafana is configured with Azure AD Single Sign-On
- **Azure AD applications are created manually** (one per subscription)
- Access is controlled through Azure AD application roles:
  - **Admin**: Full access to create and edit dashboards, users, and settings
  - **Editor**: Can create and edit dashboards but cannot manage users
  - **Viewer**: Read-only access to dashboards

## How to Access
Access Grafana at: https://grafana.<CLUSTER-NAME-IF-PRESENT>.<ENVIRONMENT>.teacherservices.cloud

## App Registration Configuration (Manual Setup)
1. Create one app registration per subscription with naming pattern:
   - `[subscription-id]-grafana` (e.g., `s189d01-grafana`)
2. Configure Web platform with:
   - Homepage URL: Any representative Grafana instance URL
   - Redirect URIs: **Add all cluster URLs** in the subscription:
     ```
     https://grafana.cluster1.development.teacherservices.cloud/login/azuread
     https://grafana.cluster1.development.teacherservices.cloud/
     https://grafana.cluster2.development.teacherservices.cloud/login/azuread
     https://grafana.cluster2.development.teacherservices.cloud/
     ```
   - Logout URL: Any representative Grafana login page
3. Create app roles:
   - Admin, Editor, and Viewer roles with exact values matching Grafana's expectations
4. Create a client secret with description "Grafana OAuth 2.0"

## Key Vault Setup (Manual)
For each subscription, add these secrets to the appropriate Key Vault:
- `GF-AZURE-CLIENT-ID`: The Application (client) ID of your app registration
- `GRAFANA-AZURE-CLIENT-ID-SECRET`: The client secret value

## Managing User Access
1. Go to Azure Portal → Microsoft Entra ID → Enterprise Applications
2. Find your application (e.g., `s189d01-grafana`)
   - Note: The application may not appear until after first sign-in
3. Navigate to "Users and groups"
4. Assign users or groups to the appropriate role

**Important Note**: Since the app registration is now created manually at the subscription level, redeploying individual clusters will **not** affect Azure AD group assignments. Group assignments only need to be set up once per subscription, not per cluster.

## Local Development
For local development or testing:
```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```
Then access Grafana at http://localhost:3000

## Infrastructure Configuration
Grafana is deployed via Terraform in `cluster/terraform_kubernetes/grafana.tf`. Key components include:
- References to manually created Azure AD application credentials from Key Vault
- Kubernetes deployment with proper environment configuration
- Ingress for external access

## Environment Variables
Grafana's behavior is configured through environment variables in the deployment:

- **Authentication Configuration**:
  - `GF_AUTH_AZUREAD_ENABLED`: Enables Azure AD authentication
  - `GF_AUTH_AZUREAD_CLIENT_ID`: Application (client) ID from Key Vault
  - `GF_AUTH_AZUREAD_CLIENT_SECRET`: Client secret from Key Vault
  - `GF_AUTH_AZUREAD_SCOPES`: OAuth scopes (typically "openid email profile")
  - `GF_AUTH_AZUREAD_ROLE_ATTRIBUTE_PATH`: Maps Azure AD roles to Grafana roles

- **Security Settings**:
  - `GF_AUTH_ANONYMOUS_ENABLED`: Set to "false" to require authentication
  - `GF_AUTH_AZUREAD_USE_PKCE`: Enables PKCE for enhanced OAuth security
  - `GF_AUTH_AZUREAD_ALLOWED_ORGANIZATIONS`: Restricts access to specific tenant

- **Server Configuration**:
  - `GF_SERVER_ROOT_URL`: External URL for Grafana (critical for proper asset loading)

## Troubleshooting
If you encounter issues with Grafana:

1. **Authentication Problems**:
   - Verify the manually created Azure AD application configuration in the Azure portal
   - Ensure all cluster redirect URIs are added to the app registration
   - Check that Key Vault contains the correct client ID and secret values
   - Ensure client secret hasn't expired

2. **UI Loading Issues**:
   - Confirm `GF_SERVER_ROOT_URL` is set correctly
   - Check ingress configuration and TLS settings

3. **Role Assignment**:
   - Verify users are assigned to the correct roles in Azure AD
   - Check role attribute mapping configuration
   - Remember the enterprise application may not appear until first sign-in
