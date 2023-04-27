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

prod-domain:
	$(if $(or ${CI}, ${CONFIRM_PROD_DOMAIN}), , $(error Missing CONFIRM_PROD_DOMAIN=yes))
	$(eval include custom_domains/config/prod-domain.sh)

dev-domain:
	$(if $(or ${CI}, ${CONFIRM_DEV_DOMAIN}), , $(error Missing CONFIRM_DEV_DOMAIN=yes))
	$(eval include custom_domains/config/dev-domain.sh)

clone:
	$(eval CLONE_STRING=-clone)

set-azure-account:
	[ "${SKIP_AZURE_LOGIN}" != "true" ] && az account set -s ${AZ_SUBSCRIPTION} || true

terraform-aks-cluster-init: set-azure-account set-azure-resource-group-tags
	terraform -chdir=cluster/terraform_aks_cluster init -reconfigure -upgrade \
		-backend-config=resource_group_name=${RESOURCE_GROUP_NAME} \
		-backend-config=storage_account_name=${STORAGE_ACCOUNT_NAME} \
		-backend-config=key=${ENVIRONMENT}.tfstate
	$(eval TF_VARS_AKS_CLUSTER=-var environment=${ENVIRONMENT} -var resource_group_name=${RESOURCE_GROUP_NAME} -var resource_prefix=${RESOURCE_PREFIX} -var config=${CONFIG} -var azure_tags='${RG_TAGS}')

terraform-aks-cluster-plan: terraform-aks-cluster-init
	terraform -chdir=cluster/terraform_aks_cluster plan -var-file config/${CONFIG}.tfvars.json ${TF_VARS_AKS_CLUSTER}

terraform-aks-cluster-apply: terraform-aks-cluster-init
	terraform -chdir=cluster/terraform_aks_cluster apply -var-file config/${CONFIG}.tfvars.json ${TF_VARS_AKS_CLUSTER} ${AUTO_APPROVE}

terraform-aks-cluster-destroy: terraform-aks-cluster-init
	terraform -chdir=cluster/terraform_aks_cluster destroy -var-file config/${CONFIG}.tfvars.json ${TF_VARS_AKS_CLUSTER} ${AUTO_APPROVE}

terraform-kubernetes-init: set-azure-account set-azure-resource-group-tags
	terraform -chdir=cluster/terraform_kubernetes init -reconfigure -upgrade \
		-backend-config=resource_group_name=${RESOURCE_GROUP_NAME} \
		-backend-config=storage_account_name=${STORAGE_ACCOUNT_NAME} \
		-backend-config=key=${ENVIRONMENT}_kubernetes.tfstate
	$(eval TF_VARS_KUBERNETES=-var environment=${ENVIRONMENT} -var resource_group_name=${RESOURCE_GROUP_NAME} -var resource_prefix=${RESOURCE_PREFIX} -var config=${CONFIG})

terraform-kubernetes-plan: terraform-kubernetes-init
	terraform -chdir=cluster/terraform_kubernetes plan -var-file config/${CONFIG}.tfvars.json ${TF_VARS_KUBERNETES}

terraform-kubernetes-apply: terraform-kubernetes-init
	terraform -chdir=cluster/terraform_kubernetes apply -var-file config/${CONFIG}.tfvars.json ${TF_VARS_KUBERNETES} ${AUTO_APPROVE}

terraform-kubernetes-destroy: terraform-kubernetes-init
	terraform -chdir=cluster/terraform_kubernetes destroy -var-file config/${CONFIG}.tfvars.json ${TF_VARS_KUBERNETES} ${AUTO_APPROVE}

check-cluster-exists:
	terraform -chdir=cluster/terraform_aks_cluster output -json | jq -e '.cluster_id' > /dev/null

terraform-init: terraform-aks-cluster-init terraform-kubernetes-init
terraform-plan: terraform-init terraform-aks-cluster-plan check-cluster-exists terraform-kubernetes-plan
terraform-apply: terraform-init terraform-aks-cluster-apply terraform-kubernetes-apply
terraform-destroy: terraform-init terraform-kubernetes-destroy terraform-aks-cluster-destroy

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

deploy-azure-resources: check-auto-approve arm-deployment # make dev deploy-azure-resources

validate-azure-resources: set-what-if arm-deployment # make dev validate-azure-resources

domain-azure-resources: set-azure-account set-azure-template-tag set-azure-resource-group-tags # make domain domain-azure-resources
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
	terraform -chdir=custom_domains/terraform/infrastructure apply -var-file workspace_variables/${DOMAINS_ID}.tfvars.json ${AUTO_APPROVE}

get-cluster-credentials: set-azure-account ## make <config> get-cluster-credentials [ENVIRONMENT=<clusterX>]
	az aks get-credentials --overwrite-existing -g ${RESOURCE_GROUP_NAME} -n ${RESOURCE_PREFIX}-tsc-${ENVIRONMENT}${CLONE_STRING}-aks

disable-cluster-node-autoscaler: set-azure-account
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
