RG_TAGS={"Product" : "Teacher services cloud"}
ARM_TEMPLATE_TAG=1.1.0
SERVICE_NAME=teacher-services-cloud
SERVICE_SHORT=tsc

ci:
	$(eval AUTO_APPROVE=-auto-approve)
	$(eval CI=true)
	$(eval SKIP_AZURE_LOGIN=true)

development:
	$(if ${ENVIRONMENT}, , $(error Missing ENVIRONMENT name))
	$(eval include cluster/config/development.sh)

test:
	$(if $(or ${CI}, ${CONFIRM_TEST}), , $(error Missing CONFIRM_TEST=yes))
	$(eval include cluster/config/test.sh)

platform-test:
	$(if $(or ${CI}, ${CONFIRM_PLATFORM_TEST}), , $(error Missing CONFIRM_PLATFORM_TEST=yes))
	$(eval include cluster/config/platform-test.sh)

production:
	$(if $(or ${CI}, ${CONFIRM_PRODUCTION}), , $(error Missing CONFIRM_PRODUCTION=yes))
	$(eval include cluster/config/production.sh)

domains:
	$(eval include cluster/config/domains.sh)

cluster-composed-variables:
	$(eval RESOURCE_GROUP_NAME=${RESOURCE_PREFIX}-tsc-${CONFIG_SHORT}-rg)
	$(eval KEYVAULT_NAME=${RESOURCE_PREFIX}-tsc-${CONFIG_SHORT}-kv)
	$(eval STORAGE_ACCOUNT_NAME=${RESOURCE_PREFIX}tsctfstate${CONFIG_SHORT})
	$(eval MANAGE_IDENTITY_NAME=${RESOURCE_PREFIX}-tsc-${CONFIG_SHORT}-id)

domains-composed-variables: domains
	$(eval RESOURCE_GROUP_NAME=${RESOURCE_PREFIX}-tscdomains-rg)
	$(eval KEYVAULT_NAME=${RESOURCE_PREFIX}-tscdomains-kv)
	$(eval STORAGE_ACCOUNT_NAME=${RESOURCE_PREFIX}tscdomainstf)

clone:
	$(eval CLONE_STRING=-clone)

set-azure-account:
	[ "${SKIP_AZURE_LOGIN}" != "true" ] && az account set -s ${AZ_SUBSCRIPTION} || true

terraform-aks-cluster-init: cluster-composed-variables set-azure-account
	terraform -chdir=cluster/terraform_aks_cluster init -reconfigure -upgrade \
		-backend-config=resource_group_name=${RESOURCE_GROUP_NAME} \
		-backend-config=storage_account_name=${STORAGE_ACCOUNT_NAME} \
		-backend-config=key=${ENVIRONMENT}.tfstate

	$(eval export TF_VAR_environment=${ENVIRONMENT})
	$(eval export TF_VAR_resource_group_name=${RESOURCE_GROUP_NAME})
	$(eval export TF_VAR_resource_prefix=${RESOURCE_PREFIX})
	$(eval export TF_VAR_config=${CONFIG})
	$(eval export TF_VAR_azure_tags=${RG_TAGS})
	$(eval export TF_VAR_managed_identity_name=${MANAGE_IDENTITY_NAME})

terraform-aks-cluster-plan: terraform-aks-cluster-init
	terraform -chdir=cluster/terraform_aks_cluster plan -var-file config/${CONFIG}.tfvars.json ${DETAILED_EXITCODE}

terraform-aks-cluster-apply: terraform-aks-cluster-init
	terraform -chdir=cluster/terraform_aks_cluster apply -var-file config/${CONFIG}.tfvars.json ${AUTO_APPROVE}

terraform-aks-cluster-destroy: terraform-aks-cluster-init
	terraform -chdir=cluster/terraform_aks_cluster destroy -var-file config/${CONFIG}.tfvars.json ${AUTO_APPROVE}

terraform-kubernetes-init: cluster-composed-variables set-azure-account
	rm -rf cluster/terraform_kubernetes/vendor/modules/aks
	git -c advice.detachedHead=false clone --depth=1 --single-branch --branch ${TERRAFORM_MODULES_TAG} https://github.com/DFE-Digital/terraform-modules.git cluster/terraform_kubernetes/vendor/modules/aks

	terraform -chdir=cluster/terraform_kubernetes init -reconfigure -upgrade \
		-backend-config=resource_group_name=${RESOURCE_GROUP_NAME} \
		-backend-config=storage_account_name=${STORAGE_ACCOUNT_NAME} \
		-backend-config=key=${ENVIRONMENT}_kubernetes.tfstate

	$(eval export TF_VAR_environment=${ENVIRONMENT})
	$(eval export TF_VAR_resource_group_name=${RESOURCE_GROUP_NAME})
	$(eval export TF_VAR_resource_prefix=${RESOURCE_PREFIX})
	$(eval export TF_VAR_config=${CONFIG})

terraform-kubernetes-plan: terraform-kubernetes-init
	terraform -chdir=cluster/terraform_kubernetes plan -var-file config/${CONFIG}.tfvars.json ${DETAILED_EXITCODE}

terraform-kubernetes-apply: terraform-kubernetes-init
	terraform -chdir=cluster/terraform_kubernetes apply -var-file config/${CONFIG}.tfvars.json ${AUTO_APPROVE}

terraform-kubernetes-destroy: terraform-kubernetes-init
	terraform -chdir=cluster/terraform_kubernetes destroy -var-file config/${CONFIG}.tfvars.json ${AUTO_APPROVE}

check-cluster-exists:
	terraform -chdir=cluster/terraform_aks_cluster output -json | jq -e '.cluster_id' > /dev/null

terraform-init: terraform-aks-cluster-init terraform-kubernetes-init
terraform-plan: terraform-init terraform-aks-cluster-plan check-cluster-exists terraform-kubernetes-plan
terraform-apply: terraform-init terraform-aks-cluster-apply terraform-kubernetes-apply
terraform-destroy: terraform-init terraform-kubernetes-destroy terraform-aks-cluster-destroy

set-what-if:
	$(eval WHAT_IF=--what-if)

set-detailed-exitcode:
	$(eval DETAILED_EXITCODE=-detailed-exitcode)

check-auto-approve:
	$(if $(AUTO_APPROVE), , $(error can only run with AUTO_APPROVE))

arm-deployment: cluster-composed-variables set-azure-account
	az deployment sub create --name "resourcedeploy-tsc-$(shell date +%Y%m%d%H%M%S)" \
		-l "UK South" --template-uri "https://raw.githubusercontent.com/DFE-Digital/tra-shared-services/${ARM_TEMPLATE_TAG}/azure/resourcedeploy.json" \
		--parameters "resourceGroupName=${RESOURCE_GROUP_NAME}" 'tags=${RG_TAGS}' \
			"tfStorageAccountName=${STORAGE_ACCOUNT_NAME}" "tfStorageContainerName=tsc-tfstate" \
			"keyVaultName=${KEYVAULT_NAME}" ${WHAT_IF}

	az deployment group create \
		--name "resource-group-tsc-$(shell date +%Y%m%d%H%M%S)" \
		--resource-group "${RESOURCE_GROUP_NAME}" \
		--template-file cluster/arm_aks_cluster/resource_group.json \
		--parameters "managedIdentityName=${MANAGE_IDENTITY_NAME}" \
		${WHAT_IF}

deploy-azure-resources: check-auto-approve arm-deployment # make test deploy-azure-resources
validate-azure-resources: set-what-if arm-deployment # make test validate-azure-resources

domains-arm-deployment: domains-composed-variables set-azure-account
	az deployment sub create --name "resourcedeploy-tscdomains-$(shell date +%Y%m%d%H%M%S)" \
		-l "UK South" --template-uri "https://raw.githubusercontent.com/DFE-Digital/tra-shared-services/${ARM_TEMPLATE_TAG}/azure/resourcedeploy.json" \
		--parameters "resourceGroupName=${RESOURCE_GROUP_NAME}" 'tags=${RG_TAGS}' \
			"tfStorageAccountName=${STORAGE_ACCOUNT_NAME}" "tfStorageContainerName=tscdomains-tfstate" \
			"keyVaultName=${KEYVAULT_NAME}" ${WHAT_IF}

deploy-domains-azure-resources: check-auto-approve domains-arm-deployment # make test deploy-domains-azure-resources
validate-domains-azure-resources: set-what-if domains-arm-deployment # make test validate-domains-azure-resources

domains-infra-init: domains-composed-variables set-azure-account
	rm -rf custom_domains/terraform/infrastructure/vendor/modules/domains
	git -c advice.detachedHead=false clone --depth=1 --single-branch --branch ${TERRAFORM_MODULES_TAG} https://github.com/DFE-Digital/terraform-modules.git custom_domains/terraform/infrastructure/vendor/modules/domains

	terraform -chdir=custom_domains/terraform/infrastructure init -reconfigure -upgrade \
		-backend-config=resource_group_name=${RESOURCE_GROUP_NAME} \
		-backend-config=storage_account_name=${STORAGE_ACCOUNT_NAME}

domains-infra-plan: domains-infra-init
	terraform -chdir=custom_domains/terraform/infrastructure plan -var-file config/${CONFIG}.tfvars.json ${DETAILED_EXITCODE}

domains-infra-apply: domains-infra-init
	terraform -chdir=custom_domains/terraform/infrastructure apply -var-file config/${CONFIG}.tfvars.json ${AUTO_APPROVE}

get-cluster-credentials: cluster-composed-variables set-azure-account ## make <config> get-cluster-credentials [ENVIRONMENT=<clusterX>]
	az aks get-credentials --overwrite-existing -g ${RESOURCE_GROUP_NAME} -n ${RESOURCE_PREFIX}-tsc-${ENVIRONMENT}${CLONE_STRING}-aks
	kubelogin convert-kubeconfig -l $(if ${AAD_LOGIN_METHOD},${AAD_LOGIN_METHOD},azurecli)

disable-cluster-node-autoscaler: cluster-composed-variables set-azure-account
	$(if $(NODE_POOL), , $(error Please specify a node pool))
	az aks nodepool update --resource-group ${RESOURCE_GROUP_NAME} --cluster-name ${RESOURCE_PREFIX}-tsc-${ENVIRONMENT}-aks --name ${NODE_POOL} --disable-cluster-autoscaler

get-cluster-nodes: get-cluster-credentials
	$(if $(NODE_POOL), , $(error Please specify a node pool))
	$(eval NODES=$(shell kubectl get nodes --selector='agentpool=${NODE_POOL}' -o jsonpath='{.items[*].metadata.name}'))

cordon-node-pool: get-cluster-nodes
	kubectl cordon ${NODES}

drain-node-pool: get-cluster-nodes
	kubectl drain ${NODES} --ignore-daemonsets --delete-emptydir-data

uncordon-node-pool: get-cluster-nodes
	kubectl uncordon ${NODES}

export-aks-resources: get-cluster-credentials
	mkdir -p ${ENVIRONMENT}-export
	cd ${ENVIRONMENT}-export && ../scripts/export_aks_resources.sh

import-aks-resources: get-cluster-credentials
	cd ${ENVIRONMENT}-export && ../scripts/import_aks_resources.sh

.PHONY: new_service
new_service:
	bash templates/new_service.sh

action-group: set-azure-account # make production action-group ACTION_GROUP_EMAIL=notificationemail@domain.com . Must be run before setting enable_monitoring=true. Use any non-prod environment to create in the test subscription.
	$(if $(ACTION_GROUP_EMAIL), , $(error Please specify a notification email for the action group))
	az group create -l uksouth -g ${RESOURCE_PREFIX}-${SERVICE_SHORT}-mn-rg --tags "Product=${SERVICE_NAME}"
	az monitor action-group create -n ${RESOURCE_PREFIX}-${SERVICE_SHORT} -g ${RESOURCE_PREFIX}-${SERVICE_SHORT}-mn-rg --action email ${RESOURCE_PREFIX}-${SERVICE_SHORT}-email ${ACTION_GROUP_EMAIL}

airbyte-init: cluster-composed-variables set-azure-account
	rm -rf airbyte/terraform/vendor/modules/aks
	git -c advice.detachedHead=false clone --depth=1 --single-branch --branch ${TERRAFORM_MODULES_TAG} https://github.com/DFE-Digital/terraform-modules.git airbyte/terraform/vendor/modules/aks

	terraform -chdir=airbyte/terraform init -reconfigure -upgrade \
		-backend-config=resource_group_name=${RESOURCE_GROUP_NAME} \
		-backend-config=storage_account_name=${STORAGE_ACCOUNT_NAME} \
		-backend-config=key=${ENVIRONMENT}_airbyte.tfstate

	$(eval export TF_VAR_environment=${ENVIRONMENT})
	$(eval export TF_VAR_resource_group_name=${RESOURCE_GROUP_NAME})
	$(eval export TF_VAR_resource_prefix=${RESOURCE_PREFIX})
	$(eval export TF_VAR_config=${CONFIG})

airbyte-plan: airbyte-init
	terraform -chdir=airbyte/terraform plan -var-file config/${CONFIG}.tfvars.json

airbyte-apply: airbyte-init
	terraform -chdir=airbyte/terraform apply -var-file config/${CONFIG}.tfvars.json ${AUTO_APPROVE}

airbyte-destroy: airbyte-init
	terraform -chdir=airbyte/terraform destroy -var-file config/${CONFIG}.tfvars.json ${AUTO_APPROVE}
