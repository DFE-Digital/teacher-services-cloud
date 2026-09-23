# Azure Container App with private PostgreSQL

This Terraform configuration deploys a standalone Azure Container App environment with:

- A public managed HTTPS endpoint for the Container App.
- VNet integration through a dedicated delegated subnet.
- Azure Database for PostgreSQL Flexible Server on a separate delegated subnet.
- Private DNS resolution and disabled public PostgreSQL network access.
- Database settings passed to the container through Container App secrets and environment variables.

The existing `../aci` deployment is independent and is not modified by this configuration.

## Prerequisites

- Terraform 1.14.
- Azure CLI authenticated with permission to create the resources.
- Access to the remote state storage account configured in `backend.tf`.
- A public container image that listens on the configured port. The example uses the supplied GHCR image on port 8080.

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with the subscription and deployment values.
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

Retrieve the public endpoint with:

```bash
terraform output container_app_url
terraform output postgres_fqdn
```

## Security notes

- PostgreSQL public network access is disabled.
- PostgreSQL is reachable through the VNet-integrated Container Apps environment and private DNS.
- Container Apps provides the public managed HTTPS endpoint; no custom domain or certificate is configured.
- Terraform state contains infrastructure metadata, the generated database password, and Container App secret values. Keep the remote state backend secured.
- Do not commit `terraform.tfvars`, state files, passwords, or certificate material.

## Cleanup

```bash
terraform destroy
```
