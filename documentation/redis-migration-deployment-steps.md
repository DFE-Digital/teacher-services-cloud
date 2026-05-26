# Migrating to Azure Managed Redis <!-- omit in toc -->

Microsoft has announced the retirement of Azure Cache for Redis and we therefore need to migrate from Azure Cache for Redis to Azure Managed Redis.

A detailed explanation of the timeline and considerations involved with the migration can be found at [Migrating to Azure Managed Redis](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/redis-migration.md).

## Individual Service Migration Steps

### Prerequisites

1. Update the Terraform plugin version to 4.71.0
   1. Search all Terraform for azurerm->version and change it to "4.71.0"
1. Add new Variables
   1. In variables.tf add the following variables.

   ```terraform
   variable "redis_managed_cache_sku_name" { default = "Balanced_B1" }
   variable "redis_managed_queue_sku_name" { default = "Balanced_B1" }
   variable "redis_mode" {
    description = "Whether to use Cache for Redis or Managed Redis"
    type        = string
    default     = "legacy" # or "managed"
    validation {
      condition     = contains(["managed", "legacy"], var.redis_mode)
      error_message = "redis_mode must be either 'legacy' (Cache for Redis) or 'managed' (Managed Redis)."
      }
    }

   ```

   1. Add the following locals

   ```terraform
    redis = {
      legacy = {
        queue_url = module.redis-queue.url
        cache_url = module.redis-cache.url
      }
      managed = {
        queue_url = module.redis-managed-queue.url
        cache_url = module.redis-managed-cache.url
      }
    }
    selected_redis = local.redis[var.redis_mode]
   ```

1. Alter the Application Redis URL value to point at the new local variables. For example:

  ```terraform
  secret_variables = {
    REDIS_QUEUE_URL = local.selected_redis.queue_url
    REDIS_CACHE_URL = local.selected_redis.cache_url
  }
  ```

4. Add new configuration blocks for Azure Managed Redis
   1. In the Terraform tf file that contains the existing Cache for RRedis configuration add redis-managed-cache and redis-managed-queue

```terraform
module "redis-managed-cache" {
  source = "./vendor/modules/aks//aks/redis_managed"

  name                  = "cache"
  namespace             = var.namespace
  environment           = local.app_name_suffix
  azure_resource_prefix = var.azure_resource_prefix
  service_name          = var.service_name
  service_short         = var.service_short
  config_short          = var.config_short

  cluster_configuration_map = module.cluster_data.configuration_map

  use_azure               = var.deploy_azure_backing_services
  azure_enable_monitoring = var.enable_alerting

  azure_managed_redis_sku = var.redis_managed_cache_sku_name
}

module "redis-managed-queue" {
  source = "./vendor/modules/aks//aks/redis_managed"

  name                  = "queue"
  namespace             = var.namespace
  environment           = local.app_name_suffix
  azure_resource_prefix = var.azure_resource_prefix
  service_name          = var.service_name
  service_short         = var.service_short
  config_short          = var.config_short

  cluster_configuration_map = module.cluster_data.configuration_map

  use_azure               = var.deploy_azure_backing_services
  azure_enable_monitoring = var.enable_alerting

  azure_managed_redis_sku = var.redis_managed_cache_sku_name
}
```

#### Switch the Environment Variable

To switch an environment you now simply set the redis_mode variable to managed in each environment tfvars file.

```terraform
 "redis_mode": "managed"
```

### Review Apps

A review app can be deployed directly with the relevant changes. Review apps do not use Azure Cache for Redis by default, and only exist for a specific Pull Request.

1. In review.tfvars.json change deploy_azure_backing_services to true and configure all [prerequisites](#prerequisites).

   ```terraform
    "deploy_azure_backing_services": true
   ```

2. Add the redis_mode variable set to managed in review.tfvars.json w

  ```terraform
    "redis_mode": "managed"
  ```

3. Create a PR and deploy a review app.
4. Check the web app is still functioning and responsive.
5. To test rollback to Cache for Redis, set redis_mode to legacy

  ```terraform
     "redis_mode": "legacy"
  ```

6. Comment out the Cache for Redis configuration block(s) to test destroying the Cache for Redis instance and relying totally on Managed Redis.
7. Redeploy the review app. You now have no Cache for Redis instances, 2 Managed Redis instances and your application will be pointing at the managed instances.
8.  Check the web app is still functioning and responsive.
9.  Add back in the commented out Cache for Redis configuration blocks.
10. Merge the PR when agreed with the service team.

### Migration Process

Follow this process for each environment. Start with the lowest environments first, and leave enough time between each environment migration to allow testing.

Production may be better implemented during a quiet time or maintenance window.

#### Migration Strategy

Decide with the service team whether they need to [migrate the data](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/redis-migration.md#3%EF%B8%8F⃣-migrate-the-data) and if so whether they want to use [export and import](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/redis-migration.md#export-and-import-data-using-an-rdb-file) or [dual-write](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/redis-migration.md#dual-write-strategy) strategies.

The procedure is more straightforward if you do not need to copy any Redis data. It is also only possible to migrate from Azure Cache for Redis Premium SKU. If your instance is currently standard, having to scale up to a Premium SKU will incur approximately 5 times the current costs (£65 to £330).

#### Raise a PR to deploy the [Managed Redis](#prerequisites) alongside the existing Cache for Redis

- This will deploy the additional Managed Redis alongside the existing Cache for Redis.
- If existing Redis data is to be migrated then see the [migrate the data](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/redis-migration.md#3%EF%B8%8F⃣-migrate-the-data) steps above.

#### Raise a PR to switch the application to point at the new Managed Redis

  ```terraform
    "redis_mode": "managed"
  ```

##### Block deployments

- Set PR approvers to 6. See GitHub Settings/Branches/BranchProtectionRules (or any other method tha stops merging to main)

##### Enable the maintenance page

- Enable using the maintenance page workflow

##### Drain In-Flight Work

Before shutting down, let all active work using Redis finish, especially background jobs and any user-facing actions.

- Let pods drain
- Pause any background workers
- Wait for queues to empty
- Check Cache for Redis activity is stopped

##### Merge the PR in to main and test the application

- If data migration is required from the existing Cache for Redis follow the [Migrate the data](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/redis-migration.md#3%EF%B8%8F⃣-migrate-the-data) steps.
- Test the application for functionality and responsiveness.

##### Unblock deployments

- Set PR approvers to 1. See GitHub Settings/Branches/BranchProtectionRules (or any other method tha stops merging to main)

##### Disable the maintenance page

- Disable using the maintenance page workflow

#### Raise a PR to remove the Cache for Redis instances

- Following an agreed period time, ensure the Cache for Redis instances are not in use and delete the Cache for Redis configuration blocks and specific variables.

## Rollback

The rollback policy will depend heavily on what data-consistency policy we wish to employ. As the existing Azure Cache for Redis instances are still up and running.

### Straight Switchback

If data retention is not required then we can raise a PR to point the REDIS_URL variables at the old Cache for Redis instances.

### Redis Data Migration

If live data from the Managed Redis instance is required then the [export and import](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/redis-migration.md#export-and-import-data-using-an-rdb-file) strategy or [dual-write](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/redis-migration.md#dual-write-strategy) strategy could be implemented with the previous RDB file or a new export.
