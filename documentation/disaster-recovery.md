# Disaster recovery <!-- omit in toc -->
The systems are built with resiliency in mind, but they may [fail in different ways](https://technical-guidance.education.gov.uk/infrastructure/disaster-recovery/) and could cause an incident.

This document covers the most critical scenarios and should be used in case of an incident. They should be regularly tested by following the [Disaster recovery testing document](disaster-recovery-testing.md).

## Service Specific Details<!-- omit in toc -->

| Service Name | Details | Link |
| ------------ | ------- | ---- |
| access-your-teaching-qualifications | [AYTQ & CTR](https://github.com/DFE-Digital/access-your-teaching-qualifications/blob/main/docs/disaster_recovery.md#aytq--ctr) | [AYTQ/CTR DR](https://github.com/DFE-Digital/access-your-teaching-qualifications/blob/main/docs/disaster_recovery.md) |

## Steps to Follow <!-- omit in toc -->

1. [Start the incident process (if not already in progress)](#start-the-incident-process-if-not-already-in-progress)
2. [Freeze the pipeline](#freeze-the-pipeline)
3. [Enable maintenance mode](#enable-maintenance-mode)
4. Restore the database
   1. [Scenario 1: Loss of database server](#scenario-1-loss-of-database-server)
      1. [Option 1: Recover from Azure backups](#option-1-recover-from-azure-backups)
      2. [Option 2. Recreate via terraform and restore from scheduled offline backup](#option-2-recreate-via-terraform-and-restore-from-scheduled-offline-backup)
   2. [Scenario 2: Loss of data](#scenario-2-loss-of-data)
5. [Validate the app](#validate-the-app)
6. [Disable maintenance mode](#disable-maintenance-mode)
7. [Unfreeze the pipeline](#unfreeze-the-pipeline)
8. [Post DR review](#post-dr-review)

### Start the incident process (if not already in progress)
Follow the [incident playbook](https://tech-docs.teacherservices.cloud/operating-a-service/incident-playbook.html) and contact the relevant stakeholders as described in [open-an-incident-thread-in-teams-any-incident-lead](https://tech-docs.teacherservices.cloud/operating-a-service/incident-playbook.html#3-open-an-incident-thread-in-teams-any-incident-lead).

### Freeze the pipeline

- Alert developers that no one should merge to main.
- In github settings, a user with repo admin privileges should update the *Branch protection rules* and set required PR approvers to 6

### Enable maintenance mode

Run the *Enable maintenance* or *Set maintenance mode* workflow for the service and environment affected.

The maintenance page message can be [updated](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/maintenance-page.md#update-content) at any time during the incident.

e.g. https://claim-additional-payments-for-teaching-test-web.test.teacherservices.cloud will now display the maintenance page and

https://claim-additional-payments-for-teaching-temp.test.teacherservices.cloud will display the application.

Note that the available temp route can be seen on the completed maintenance workflow summary view in github.

### Database Failure Scenarios:
- [Scenario 1: Loss of database server](#scenario-1-loss-of-database-server)
- [Scenario 2: Loss of data](#scenario-2-loss-of-data)

### [Scenario 1: Loss of database server](https://technical-guidance.education.gov.uk/infrastructure/disaster-recovery/#loss-of-database-instance)

In this scenario, the [Azure Postgres flexible server](https://portal.azure.com/?feature.msaljs=true#browse/Microsoft.DBforPostgreSQL%2FflexibleServers) and the database it contains have been completely lost.

There are two main options for recovery.

[Option 1](#option-1-recover-from-azure-backups): Recover the deleted server from the Azure backups. These can be used to recover a dropped Azure Database for PostgreSQL flexible server resource within five days from the time of server deletion. Note that Microsoft do not guarantee this will work as there are other factors involved. See [How to restore a dropped server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-restore-dropped-server).

[Option 2](#option-2-recreate-via-terraform-and-restore-from-scheduled-offline-backup): Recreate the Postgres server via terraform, and then restore from the nightly github workflow scheduled database backups. These backups are stored in [Azure storage accounts](https://portal.azure.com/?feature.msaljs=true#browse/Microsoft.Storage%2FStorageAccounts) and kept for 7 days.

[Option 1](#option-1-recover-from-azure-backups) should be attempted first, as it can recover very close to the point of server loss, minimising any potential data loss. Option 2 would be used if the first option fails to work.

#### Option 1: Recover from Azure backups

- Run the restore-deleted-postgres workflow to recreate the missing postgres database.
- provide the following details.

| Required Parameter | Description | Options |
|--------------------|-------------|---------|
| Environment to restore | The environment to restore the database server in | test, preproduction, production etc. |
| Confirm production | A true/false confirmation if running in production | true, false |
| Restore point in time | Restore point in time in **UTC**.<br/>The restore point provided should be at least 10 minutes after the server was deleted and should be in the past, this is to provide time for the backup to become available.<br/>You should convert the time to UTC before actually using it. When you record the time, note what timezone you are using. Especially during BST (British Summer Time). | e.g. 2024-07-24T06:00:00 |
| Server name to restore | The server name to be restored | [AYTQ](https://github.com/DFE-Digital/access-your-teaching-qualifications/blob/main/docs/disaster_recovery.md#aytq--ctr) |


#### Option 2. Recreate via terraform and restore from scheduled offline backup

##### Check/Delete Monitor Diagnostics

- Check and delete any postgres diagnostics remaining for the deleted instance in https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/diagnosticsLogs as the later deploy to rebuild postgres will fail if it remains. e.g. search using subscription s189-teacher-services-cloud-test and resource group s189t01-ittms-stg-pg and look for enabled Diagnostic settings. To do this select the `subscription` & `resource group` from the dropdown filter and select `Azure database for PostgresSQL flexible server` from the `resource type`. If the postgres flexible server has `Diagnostic Status` of `Enabled` then select the server, choose `edit setting`, and delete. Note the diagnostic setting name will end with -diagnostics.
If you don't see the s189 subscription check you don't have it excluded in your default subscription filter at https://portal.azure.com/#settings/directory
- Azure Monitor Diagnostics can be viewed using the CLI command. The CLI command requires a resource id which can be obtained via the portal.
  - Goto to the portal and navigate to the database `Overview`
  - Click on `JSON View`.
  - Copy the `Resource Id` shown on the top.
  - `az monitor diagnostic-settings list --resource <resource-id>`

Links to individual service environments, subscriptions and resource groups.
| Service Name |
|--------------|
| [AYTQ](https://github.com/DFE-Digital/access-your-teaching-qualifications/blob/main/docs/disaster_recovery.md#recreate-the-postgres-server-via-terraform) |

##### Run Workflow

- Run the `deploy` workflow to recreate the missing postgres database as detailed below. This will create an empty database for you to restore the data into in the next step.
- As the maintenance page has been enabled, you will need to:
  - create a branch from main
  - update the terraform application config as per: [configure-terraform-to-keep-deploying-the-application](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/maintenance-page.md#configure-terraform-to-keep-deploying-the-application)
  - push the branch to github (no need to create a PR)
  - run the deploy workflow using your branch

Note: The deploy workflow may fail on steps after the postgres server creation e.g. smoke tests or database migrations. This is expected due to the enabling of maintenance page. You can confirm the server is available via a healthcheck url that checks the database status (if your service has one), or via the azure portal. The healthcheck url will need to use the temp route.

#### Restore the data from previous backup in Azure storage

Run the `Restore database from Azure storage` workflow.

### Scenario 2: [Loss of data](https://technical-guidance.education.gov.uk/infrastructure/disaster-recovery/#data-corruption)

In the case of data loss or corruption, we need to recover the data as soon as possible in order to resume normal service.

The application database is an Azure flexible postgres server. This server has a point-in-time restore (PTR) ability with the resolution of 1 second, available between 5min and 7days. PTR allows you to restore the live server to a point-in-time on a new copy of the server. It does not update the live server itself in any way. Once the new server is available it can be accessed using [konduit.sh](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/scripts/konduit.sh) to check previous data, and data can then be recovered to the original server.

The goals of this scenario are:
- Create a separate new postgres database server
- Restore data from the current live database to the new postgres database server from a particular point in time
- Update data into the live database from the new PTR server

The steps in this scenario are:

1. [Stop the service as soon as possible](#stop-the-service-as-soon-as-possible)
1. [Start the incident process](#start-the-incident-process-if-not-already-in-progress)
1. [Freeze the pipeline](#freeze-the-pipeline)
1. [Enable the maintenance page](#enable-maintenance-mode)
1. [Backup the database (optional)](#back-up-the-database-optional)
1. [Restore the postgres database](#restore-postgres-database)
1. [Upload restored database to Azure storage](#upload-restored-database-to-azure-storage)
1. [Validate data](#validate-data)
1. [Restore data into the live server](#restore-data-into-the-live-server)
1. [Restart applications](#restart-applications)
1. [Validate app](#validate-the-app)
1. [Disable the maintenance page](#disable-maintenance-mode)
1. [Unfreeze the pipeline](#unfreeze-the-pipeline)
1. [Tidy up](#tidy-up)
1. [Post DR review](#post-dr-review)

#### Stop the service as soon as possible
If the service is available, even in a degraded mode, there is a risk users may make edits and corrupt the data even more. Or they might access data they should not have access to. To prevent this, stop the web app and/or workers as soon as possible. This can be completed using the kubectl scale command

Example (update the namespace and deployment names as required)
- `kubectl -n bat-staging get deployments`
- `kubectl -n bat-staging scale deployment itt-mentor-services-staging --replicas 0`
- `kubectl -n bat-staging scale deployment itt-mentor-services-staging-worker --replicas 0`

Note: You can [enable maintenance mode](#enable-maintenance-mode) first, however it is still recommended to scale down the web and worker apps to prevent any side effects from occurring.

#### Back up the database (optional)

This step is optional, however if users have entered data or new users have signed up since the database corruption we don't want to lose that data and we may need to keep this data for reconciliation later on. To do that we need to back up the current state of the database before restoring the previous data. This backup can then be used to extract any new data entered since the corruption, and also to compare against the restored data to understand what was lost.

- Use the `Backup database to Azure storage` workflow to save a copy of the flawed database. Use a specific name to identify the backup file later on.


#### Restore postgres database
First we must restore the database to a new postgres server using the point in time restore (PTR) feature. This will create a new copy of the database as it was at the point in time chosen for the restore, and this copy will be on a new postgres server. The live server will not be affected by this process, and the restored data can be checked and validated before being copied back into the live server.

Run the [Restore database from point in time to new database server workflow](https://github.com/DFE-Digital/access-your-teaching-qualifications/actions/workflows/database-restore-ptr.yml) using a time before the data was deleted. If you need to rerun the workflow, it may fail if the new server was already created. Override the new server name to work around the issue.

| Required Parameter | Description | Options |
|--------------------|-------------|---------|
| Environment to restore | The environment to restore the database server in. | test, preproduction, production etc. |
| Confirm production | A true/false confirmation if running in production. | true, false |
| Restore point in time | Restore point in time in **UTC**.<br/>The restore point provided should be at least 10 minutes after the server was deleted and should be in the past, this is to provide time for the backup to become available.<br/>You should convert the time to UTC before actually using it. When you record the time, note what timezone you are using. Especially during BST (British Summer Time). | e.g. 2024-07-24T06:00:00 | e.g. 2024-07-24T06:00:00 |
| Name of the new database server. | The name to be used for the new server. | Default is <original-server-name>-ptr. |

#### Upload restored database to Azure storage

At this point you have restored the database at the point in time you want to recover onto a new postgres server. You now need to get this data back into the live server. To do that, you first need to back up the restored database to Azure storage so that it can then be used as the source for restoring into the live server.

This step is required even if you completed the optional backup step before restoring the PTR copy, as that backup would have been taken of the corrupted data, whereas this backup will be taken of the restored data.

- Use the `Backup database to Azure storage` workflow and choose the restored server as input. Use a specific name to identify the backup file later on.

#### Validate data
It may be necessary to connect to the PTR postgres server for troubleshooting, before deciding on a full restore or otherwise. For instance, the PTR restore may have to be rerun with a different date/time.

Konduit allows you to connect to a backend service via an app instance, and can be used to connect to the PTR postgres server to check the data before restoring to the live server. This can be used to check if the restore was successful, and if the correct point in time was chosen for the restore.

The following needs to be done locally within a cloned copy of the repository, and requires konduit.sh to be installed locally.

To connect to the PTR postgres copy using `psql` via konduit:
- Install `konduit.sh` locally using the `make` command
- Run: `bin/konduit.sh -x -n <namespace-of-deployment> -s <name-of-ptr-server> <name-of-deployment> -- psql`

e.g. `bin/konduit.sh -x -n tra-test -s s189t01-ittms-stg-pg-ptr itt-mentor-services-staging -- psql`

To connect to the existing live postgres server for comparison:
- Run: `bin/konduit.sh -x name-of-deployment -- psql`

e.g. `bin/konduit.sh -x itt-mentor-services-staging -- psql`

#### Restore data into the live server

- To perform a complete restore of the live server from the PTR copy, use the `Restore database from Azure storage` workflow and choose the backup file created above to restore to the live postgres server.
- Note that when entering the backup filename that the name entered in the `Upload restored database to Azure storage` job should be appended with `.sql.gz` so that the file can correctly be looked up.

#### Restart applications

Run the following commands

Example (update the namespace, deployment names and replicas as required)
- `kubectl -n bat-staging get deployments`
- `kubectl -n bat-staging scale deployment itt-mentor-services-staging --replicas 2`
- `kubectl -n bat-staging scale deployment itt-mentor-services-staging-worker --replicas 1`

### Validate the app

- Confirm the app is working and can see the restored data. The app is available on the [temporary ingress](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/maintenance-page.md#fail-over) URL.

e.g. https://claim-additional-payments-for-teaching-temp.test.teacherservices.cloud will display the application.

- You may also want to check any healthcheck urls (e.g. /healthcheck), admin interfaces, api requests, etc

Individual service details of environment and healthcheck URLs

| Service Name |
|--------------|
| [AYTQ/CTR](https://github.com/DFE-Digital/access-your-teaching-qualifications/blob/main/docs/disaster_recovery.md#validate-app) |

### Disable maintenance mode

- Run the `Disable maintenance` or `Set maintenance mode` workflow for the service and environment affected.

### Unfreeze the pipeline

- Alert developers that merge to main is allowed.
- In github settings, update the Branch protection rules and set required PR approvers back to 1

#### Tidy up

If a PTR was run in [Option 2](#option-2-recreate-via-terraform-and-restore-from-scheduled-offline-backup), the database copy server should be deleted. To do this locate the database server in the Azure portal and delete it. Locating the database server can be done by going to the resource group for the environment and looking for a server with the name used when creating the PTR copy. For example, within the test environment navigating to the resource group s189t01-aytq-ts-rg and looking for a server with the name `<original-server-name>-ptr` or the custom name used when creating the PTR copy.

If this document is being followed as part of a DR test, then [complete DR test post scenario steps](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/disaster-recovery-testing.md#post-scenario-steps)

### Post DR review
- Schedule an incident retro meeting with all the stakeholders
- Review the incident and fill in the incident report
- Raise trello cards for any process improvements
