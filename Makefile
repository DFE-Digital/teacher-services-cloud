ci:
	$(eval AUTO_APPROVE=-auto-approve)

development:
	$(if ${ENVIRONMENT}, , $(error Missing ENVIRONMENT name))
	$(eval include cluster/config/development.sh)

test:
    $(eval include cluster/config/test.sh)

platform-test:
	$(eval include cluster/config/platform-test.sh)

psp-poc:
	$(eval include cluster/config/psp_poc.sh)

prod-domain:
	$(eval include custom_domains/config/prod-domain.sh)

dev-domain:
	$(eval include custom_domains/config/dev-domain.sh)

set-azure-account:
	az account set -s ${AZ_SUBSCRIPTION}

terraform-init: set-azure-account
	terraform -chdir=cluster/terraform init -reconfigure -upgrade \
		-backend-config=resource_group_name=${RESOURCE_GROUP_NAME} \
		-backend-config=storage_account_name=${STORAGE_ACCOUNT_NAME} \
		-backend-config=key=${ENVIRONMENT}.tfstate
	$(eval TF_VARS=-var environment=${ENVIRONMENT} -var resource_group_name=${RESOURCE_GROUP_NAME} -var resource_prefix=${RESOURCE_PREFIX} -var config=${CONFIG})

terraform-plan: terraform-init
	terraform -chdir=cluster/terraform plan -var-file config/${CONFIG}.tfvars.json ${TF_VARS}

terraform-apply: terraform-init
	terraform -chdir=cluster/terraform apply -var-file config/${CONFIG}.tfvars.json ${TF_VARS} ${AUTO_APPROVE}

terraform-destroy: terraform-init
	terraform -chdir=cluster/terraform destroy -var-file config/${CONFIG}.tfvars.json ${TF_VARS}

set-what-if:
	$(eval WHAT_IF=--what-if)

check-auto-approve:
	$(if $(AUTO_APPROVE), , $(error can only run with AUTO_APPROVE))

set-azure-template-tag:
	$(eval ARM_TEMPLATE_TAG=1.1.0)

set-azure-resource-group-tags: ##Tags that will be added to resource group on its creation in ARM template
	$(eval RG_TAGS=$(shell echo '{"Portfolio": "Early Years and Schools Group", "Parent Business":"Teacher Training and Qualifications", "Product" : "Teacher services cloud", "Service Line": "Teaching Workforce", "Service": "Teacher Training and Qualifications", "Service Offering": "Teacher services cloud", "Environment" : "$(ENV_TAG)"}' | jq . ))

arm-deployment: set-azure-account set-azure-template-tag set-azure-resource-group-tags
	az deployment sub create --name "resourcedeploy-tsc-$(shell date +%Y%m%d%H%M%S)" \
		-l "UK South" --template-uri "https://raw.githubusercontent.com/DFE-Digital/tra-shared-services/${ARM_TEMPLATE_TAG}/azure/resourcedeploy.json" \
		--parameters "resourceGroupName=${RESOURCE_GROUP_NAME}" 'tags=${RG_TAGS}' \
			"tfStorageAccountName=${STORAGE_ACCOUNT_NAME}" "tfStorageContainerName=tsc-tfstate" \
			"keyVaultName=${KEYVAULT_NAME}" ${WHAT_IF}

deploy-azure-resources: check-auto-approve arm-deployment # make dev deploy-azure-resources AUTO_APPROVE=1

validate-azure-resources: set-what-if arm-deployment # make dev validate-azure-resources

domain-azure-resources: set-azure-account set-azure-template-tag set-azure-resource-group-tags # make domain domain-azure-resources AUTO_APPROVE=1
	$(if $(AUTO_APPROVE), , $(error can only run with AUTO_APPROVE))
	az deployment sub create --name "resourcedeploy-tscdomains-$(shell date +%Y%m%d%H%M%S)" \
	    -l "UK South" --template-uri "https://raw.githubusercontent.com/DFE-Digital/tra-shared-services/${ARM_TEMPLATE_TAG}/azure/resourcedeploy.json" \
		--parameters "resourceGroupName=${RESOURCE_GROUP_NAME}" 'tags=${RG_TAGS}' \
			"tfStorageAccountName=${STORAGE_ACCOUNT_NAME}" "tfStorageContainerName=tscdomains-tfstate" \
			"keyVaultName=${KEYVAULT_NAME}" ${WHAT_IF}

domains-infra-init: set-azure-account
	terraform -chdir=custom_domains/terraform/infrastructure init -reconfigure -upgrade \
		-backend-config=workspace_variables/${DOMAINS_ID}_backend.tfvars

domains-infra-plan: domains-infra-init
	terraform -chdir=custom_domains/terraform/infrastructure plan -var-file workspace_variables/${DOMAINS_ID}.tfvars.json

domains-infra-apply: domains-infra-init
	terraform -chdir=custom_domains/terraform/infrastructure apply -var-file workspace_variables/${DOMAINS_ID}.tfvars.json
