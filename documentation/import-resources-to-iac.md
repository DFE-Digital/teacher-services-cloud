# Import resources to Terraform
In some cases, resources are created in the Azure/AWS consoles or by other means outside of Terraform. Ideally we want infrastructure to be controlled using IAC, so the resources need to be retroactively imported into terraform.

There are two main ways to do this, in both cases the code needs to be prewritten to match what is currently deployed - If the resource is configured differently in the code than to what is actually deployed, it will still import (provided that the code is syntactically correct and does not contain any errors), however, the next plan will update the resource with the new config, so unless this is desired it must be corrected before the next apply. It is important to check this, as some config changes will force the resource to be recreated, which in some cases can cause loss of data, such as with storage accounts, keys vaults and databases. If a resource has been imported and the plan shows unwanted changes, block deployments to the service (by increasing the number of reviewers required for PRs) until the code is updated and the issue is resolved

## Using the command line
The Terraform CLI includes an import command, which allows individual resources to be imported to the state file using the following syntax:
```
terraform import <terraform_resource_in_code> <resource_id_from_cloud_provider>
```
The terraform_resource_in_code refers to the resource identifier in terraform e.g module.resource_type.resource_name <br>
The resource_id_from_cloud_provider refers to the id assigned to the deployed resource by the hosting provider, for AWS this is typically the ARN, and for Azure this is typically the resource ID. There are some variations to this, and the correct command formatting can be found at the bottom of the resource page in the Terraform registry here: https://registry.terraform.io/namespaces/hashicorp

The simplest way to do this in an existing service is to include an additional command in the makefile, as this will allow it to use the same nested terraform-init process as other commands in the repo, such as in the below example:
```
.PHONY: terraform-import: 
terraform-import: terraform-init
	terraform -chdir=terraform/application import -var-file "config/${CONFIG}.tfvars.json" $(RESOURCE) $(ID)
```
This may not be identical for every repo due to some having varying file structures, but in essence it should import the resource by running the command with 3 arguments:
- environment
- terraform resource
- cloud resource id

For example:
```
make test terraform-import module.storage.azurerm_storage_container.containers["<container_name>"] "/subscriptions/<subscription_id>/resourceGroups/<resourc_group_name>/providers/Microsoft.Storage/storageAccounts/<storage_account_name>/blobServices/default/containers/<contianer_name>"
```

It is possible that the code will need to be rewritten in some cases to allow a resource to be imported without introducing new changes. For example, the following PR was to import an additional storage account container into the test environment of sap-public, however, the list of containers was hardcoded in the tf file, meaning that once this was imported into test, future plans against other environments would create the same container despite it not being needed. In this case, the code was updated so the containers list was controlled using a variable at the environment level, meaning the test import had no effect on other environments. [GitHub PR](https://github.com/DFE-Digital/sap-public/pull/440)

## Using import blocks
Another option to import into Terraform is to use import blocks. These code blocks work similarly to the import command, in that they use the terraform resource in the code, and the resource ID of the cloud provider, to add the manually deployed resource to the state. This is achieved using the following syntax:
```
import {
  to = <terraform_resource_in_code>
  id = "<resource_id_from_cloud_provider>"
}
```

As with the previous example, it is possible that some imports will be environment-specific, however, this cannot be achieved using variables as the terraform resource reference needs to be interpreted as terraform code, not a literal string from a json file. To work around this, a for_each can be used with a conditional statement in the import block to only apply if it matches a specific environment:
```
import {
  for_each = var.app_environment == "test" ? [1] : null
  to       = module.storage.azurerm_storage_container.containers["<container_name>"]
  id       = "/subscriptions/<subscription_id>/resourceGroups/<resourc_group_name>/providers/Microsoft.Storage/storageAccounts/<storage_account_name>/blobServices/default/containers/<contianer_name>"
}
```
An example of using import blocks for importing to Terraform can be found in the following PR [GitHub PR](https://github.com/DFE-Digital/teaching-vacancies/pull/9170)

## Which option to use
Both of the options above are effective, however, they have separate benefits. As a general rule of thumb, the chosen method will depend on the complexity of the import task.

1. Importing in the CLI - This method is best for simpler import tasks, of either a single or small number of resources. If the import is fairly striaght forward, it can be done on a per-resource basis in the CLI and only block other applies for a short time before being merged in. Simply import the resource using the command covered above, run a plan locally to confirm the config lines up and there are no unexpeted changes, then raise a PR to merge the changes into main. As mentioned above, if there are any unexpected changes in the plan following the import, increase the number of reviewers for PRs to avoid any other merges, and resolve the issue to avoid the resource being updated/recreated and a potential loss of data.

2. Importing using import blocks - This method is slightly less "clean" as it involves writing additional code for the imports as well as the resource code itself. The benefit to this, however, is that the local plan can be run before the import actually takes place. This means that any unwanted or unexpected changes to the resource through mismatched code, can be addressed before the resources are ever being written to the state, meaning it does not introduce any blockers for other applies and also does not introduce a risk of resource recreation or data loss. The plan will show all resources that are being imported, as well as any changes to the resources once the import takes place. This method is the better approach for larger and more complex import tasks that are more time consuming.