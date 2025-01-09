# Platform set-up

## Ingress DNS

There are two DNS zones for ingress DNS:

- teacherservices.cloud (prod zone)
- development.teacherservices.cloud (dev zone)

### Zone Build

```
make {development/production} domains-infra-{plan/apply}
```

There is also an NS record for delegation from teacherservices.cloud to development.teacherservices.cloud,
which is created if delegation_name and delegation_ns are set in tscp.tfvars.json

If the development zone NS records are changed for any reason, then these variables must be updated manually,
and the prod zone updated.

### Register new domain
The Infrastructure Operations team registered the teacherservices.cloud domain in route53. It is valid for 1 year and renews automatically. A senior civil servant is recorded as contact and receives renewal notices. The domains is configured with the nameservers for the teacherservices.cloud zone, built above.

### Ingress DNS record

We use a wildcard DNS record for the ingress domain, which is the default domain of any application deployed to the cluster.

For the development clusters, on cluster build this record will be automatically created in the dev DNS zone.

## Ingress TLS

We use a wildcard certificate for the default domain of any application deployed to the cluster. Certs are created from Azure Keyvault (manually), and then loaded into the cluster using terraform on cluster build.

Initial set up requires manual steps. Then renewals are automated.

### Add Globalsign domain
The teacherservices.cloud domain is created in route53 and owned by the Infrastructure Operations team. The following steps were required for allowing teacherservices.cloud top domain. They won't be required for new clusters under the same top domain.

#### Generate value for DNS record

1. Login to GlobalSign and select Managed SSL, then Add Domain under `O: Department for Education`
1. Enter "teacherservices.cloud"

Follow instructions after Domain renewal.

#### Domain renewal
The domain expires every year and must be renewed manually.

1. Login to GlobalSign, select Managed SSL, then Manage Domains under `O: Department for Education`
1. Click on the `Renew` button against the teacherservices.cloud domain
1. Verify the details and click Continue

Follow instructions in the next section.

#### Continuation
1. Add point of contact (a senior Civil Servant)
1. Select DNS Verification (on next page)
1. Confirm the details and click Complete. The feedback should look something like:
    ```
    Thank you for submitting your application. Your order number is XXX.
    Domain: teacherservices.cloud
    The DNS value for this domain is: _globalsign-domain-verification=XXXXXXXXXXXXXXXXXX
    ```
1. Update the value of `_globalsign-domain-verification` in `custom_domains/terraform/infrastructure/config/tscp.tfvars.json`

#### Verify Domain
1. Login to GlobalSign, select Managed SSL, then Manage Domains under `O: Department for Education`
1. Search for teacherservices.cloud and select the green check mark
1. Select verify domain
1. You should receive a feedback: "Your domain has been successfully verified."

#### Create Certificate in Azure
Follow the [technical guidance on certificates](https://technical-guidance.education.gov.uk/infrastructure/security/ssl-certificates/#automatic-via-key-vault
).

1. Ensure CAA record (for teacherservices.cloud) allows GlobalSign. See [terraform configuration](https://github.com/DFE-Digital/terraform-modules/blob/main/dns/zones/resources.tf) or [GlobalSign documentation](https://support.globalsign.com/ssl/general-ssl/how-add-dns-caa-record-dns-zone-file).
1. Navigate to Key Vaults, select the applicable Key vault
1. Create a new certificate using the defaults from the above documentation and the following properties ([config] refers to the value defined in [variables.tf](cluster/terraform_kubernetes/variables.tf)):
    - Certificate Name: [config]-teacherservices-cloud (for development: cluster[N]-development-teacherservices-cloud)
    - Subject CN: *.[config].teacherservices.cloud (for development: *.cluster[N].development.teacherservices.cloud)
    - DNS Names: 0
    - Validity: 12 months

Add the certificate name to the [terraform configuration](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/cluster/terraform_kubernetes/config/test.tfvars.json#L20) with the [ingress_cert_name variable](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/cluster/terraform_kubernetes/variables.tf#L22). On cluster build, terraform will load the cert into a kubernetes secret,
and this will be set as the default-ssl-certificate in the nginx ingress.

## Create new cluster configuration
When creating a brand new cluster with its own configuration, follow these steps:
- Create the config files in:
    - cluster/config
    - cluster/terraform_aks_cluster/config
    - cluster/terraform_kubernetes/config
- Create the new config entry in the Makefile (e.g. `test:`)
- Create low-level terraform resources: `make <config> validate-azure-resources` and `make <config> deploy-azure-resources`
- Request the Cloud Engineering Team to assign role "Network Contributor" to the new managed identity on the new resource group
- Create the admin AD group following the [AD groups documentation](https://educationgovuk.sharepoint.com/sites/teacher-services-infrastructure/SitePages/AKS%20AD%20groups.aspx)
- Use the group object id in the admin_group_id variable
- Use PIM for groups to activate membership of the admin group
- Run: `make <environment> terraform-apply`
- Configure a domain pointing at the new ingress IP following [Cluster DNS zone configuration](#cluster-dns-zone-configuration)
- Create or update the user AD groups as per the [AD groups documentation](https://educationgovuk.sharepoint.com/sites/teacher-services-infrastructure/SitePages/AKS%20AD%20groups.aspx)

## Deployment workflow
When a pull request is created, the `Deploy Cluster` workflow runs and validates the terraform code.

When the pull request is merged, the workflow continues and deploys successively the `platform-test`, `test` and `production` clusters. Then it updates the domains in the `development` and `production` zones.

The jobs run in separate Github environments. Each environment contains secrets `AZURE_CLIENT_ID` and `AZURE_SUBSCRIPTION_ID` required for [Github OIDC authentication](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure), as well as `AZURE_TENANT_ID` stored as repository secret. The variables correspond to Entra ID app registrations that have the `s189-Contributor and Key Vault editor` role.

[Federated credentials](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azp#github-actions) are created manually by an app registration owner. Each one authenticates a Github environment in the teacher-services-cloud repository.

The Github environment variables `TEST_APP_DEPLOYMENT` enables the application deployment smoke test after the deployment. It simulates a typical application deployment using OIDC by deploying *ITT mentor services* to the cluster, testing, and deleting the application. `ITTMS_ENVIRONMENT` points at the chosen environment in [ITTMS](https://github.com/DFE-Digital/itt-mentor-services).
