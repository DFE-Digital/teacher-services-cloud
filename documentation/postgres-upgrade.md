# Postgres major version upgrade

This document covers the major version upgrade procedure for Azure Postgres Flexible servers

## Overall Procedure

This process uses the Azure PostgreSQL [in place major version upgrade feature](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-major-version-upgrade). This feature will
- run pre checks to check for any upgrade incompatabilities.
- create sanpshots to automatically recover if there is an issue during the upgrade
- allows skipping verions and going directly to a higher version e.g. 14 -> 16

Note that this is an offline process and the service will be unavailable while the upgrade takes place. Azure advise that while most upgrades complete in under 15 minutes, the actual duration depends on the size and complexity of the database. Initial testing has seen upgrades take 15-20 minutes, but larger database will take longer. Upgrading a similar sized non-production database will give an indication of the production upgrade time.

## Notes

As of 02/08/2025 there are several terraform issues with Postgres upgrades.
- terraform does not currently recognise version 17 as a valid option. This is because the azure api has not yet been updated, although that should happen soon. We would have to update the terraform module to ignore the database version if any database is updated to 17 outside of terraform, otherwise deploy pipelines would fail.
- the terraform azurerm provider must be at least version 4.27.0 otherwise terraform will replace the postgres server during any upgrade. Version 4.27.0 allows changing the create_mode to "Update" and terraform will then run the in place upgrade feature. We currently use version 3 of the azurerm provider and while initial testing shows the upgrade works fine, there were issues seen with resources that mean thorough testing will be required before we upgrade the provider. For that reason this process does not use terraform to upgrade the server.

## Prerequisites

- Check available storage space for each database server
    - Before starting the upgrade, ensure that your server has at least 10–20% free storage available.
    - Increase storage for any databases that don't have sufficient space available
- check limitations and exclusions
    - see https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-major-version-upgrade#upgrade-considerations-and-limitations
- add commands to the Makefile
    - enable/disable server logs
    - scale up/down commands
- Speak with the service team
    - Confirm the target upgrade version
    - advise the process, and arrange dates and any outage windows
    - advise of any pre work

## Review apps

A review app can be deployed directly with the target Postgres version. Review apps do not use Azure PostgreSQL by default, and only exist for a specific Pull Request. So no upgrade is required.
- create a PR with the target version and deploy a review app
- test the review app as required
- merge the PR when agreed with the service team. This may be after the production server is upgraded or they might want to do this straight away.

## Upgrade Process

Follow this process for each environment. Start with the lowest environments first, and leave enough time between each environment upgrade to allow testing.

### Database checks
Connect to the database using konduit, and check which tables have been analyzed using the queries below
```sql
select relname, last_autoanalyze, last_analyze FROM pg_stat_user_tables group by 1, 2, 3 order by 2, 3 desc;
select relname, n_live_tup, n_dead_tup from pg_stat_user_tables group by 1, 2, 3 order by 2, 3 asc;
```
After upgrade these stats will be reset to 0.
While auto analyze will eventually run against heavily modified tables, it will be best to manually analyze tables after the upgrade.

### Raise a PR with the new version for the target environment
- this will be merged AFTER the upgrade has been completed

### Block deployments
- set PR approvers to 6 (or any other method that stops merging to main)

### Enable Postgres server logs
- make env enable-pglogs

### Enable the maintenance page
- enable using the maintenance page workflow

### Shutdown the application (web and worker)
- kubectl -n namespace deployment/service-env[-worker] --scale replicas=0

or
- make env show-service
- keep a note of number of replicas for when the service is started after upgrade
- make env scale-app REPLICAS=0
- make env scale-worker REPLICAS=0
- make env show-service
- Make a note of the shutdown time, as this can be used for PTR recovery if required

### Run a database backup [production]
- while a PTR can be used for recovery, we advise running a separate offline backup for production environments

### Start the upgrade
- Select upgrade within the Azure portal for the target database server

### Monitor the upgrade
- the upgrade mostly happens in the background. Initial testing has seen upgrades take 15-20 minutes, but larger database will take longer.
- server upgrade logs will be created, but they won't be available until the upgrade completes
- if diagnostic logging is enabled, server logs can be viewed but they don't log any upgrade commands, just shutdowns and restarts, and weren't seen to be that useful.

### Check status on completion
- check database state in the portal (should be 'Ready')
- download and check the server upgrade logs
    - make env list-pglogs
    - make env download-pglogs LOG_NAME=name-of-the-upgrade-log

### Analyse the database
- Azure recommend running analyse against the database
- After the major version upgrade is complete, we recommend running the ANALYZE command in each database to refresh the pg_statistic table. Missing or stale statistics can lead to bad query plans, which in turn might degrade performance and take up excessive memory.
- using the list of table stats taken before the upgrade, analyze selected tables manually using ANALYZE table_name;

### Start the application
- kubectl -n namespace deployment/service-env[-worker] --scale replicas=n

or
- make env scale-app REPLICAS=n
- make env scale-worker REPLICAS=n
- make env show-service

### Service team check the app works as expected
- access via the temp route
- if not ok, follow the rollback procedure

### Disable the maitenance page
- disable using the maintenance page workflow

### Merge PR with the new server version
- run deploy-plan from the PR branch before merge to ensure Postgres will not be changed
- do not run any other PR's before this one, otherwise postgres will be downgraded

### Unblock deployments
- reset PR approvers to 1

### Disable server logs
- make env disable-pglogs (any existing logs will remain within the existing retention period)

## Rollback

There are two main options for rolling back the upgrade.
In all cases make sure the maintenance page is enabled, and the service is down.
Option 2 is the quickest.
If the server has already been made available to users, then rolling back will cause the loss of new or changed data since the upgrade.

1. Use Point in time restore
- Run the PTR workflow using the time just before the upgrade was started
- Backup the PTR server
- Delete the upgraded database server, and redeploy (with maintenance page enabled) using the original postgres version to build an empty server
- Restore the PTR server backup into the empty server

2. Use the offline backup taken just before the upgrade
- Run the Postgres restore workflow using the backup
