# Disaster recovery

The systems are built with resiliency in mind, but they may [fail in different ways](https://technical-guidance.education.gov.uk/infrastructure/disaster-recovery/) and could cause an incident.

This document covers the most critical scenarios and should be used in case of an incident. They should be regularly tested by following the [Disaster recovery testing document](disaster-recovery-testing.md).

If this document is being followed as part of a DR test, then the following steps should have already been completed by the devops team
- [create DR test documentation requirements](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/disaster-recovery-testing.md#documentation-requirements)
- either [DR test Scenario 1 setup](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/disaster-recovery-testing.md#scenario-1-loss-of-database-instance) or [DR test Scenario 2 setup](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/disaster-recovery-testing.md#scenario-2-loss-of-data) depending on the scenario being tested

## Scenario 1: [Loss of database server](https://technical-guidance.education.gov.uk/infrastructure/disaster-recovery/#loss-of-database-instance)

In this scenario, the [Azure Postgres flexible server](https://portal.azure.com/?feature.msaljs=true#browse/Microsoft.DBforPostgreSQL%2FflexibleServers) and the database it contains have been completely lost.

As the point-in-time and snapshot backups created by the Azure Postgres service may not be available if it's been deleted or if there is an Azure region issue, the Postgres server will have to be recreated and the database restored from the nightly github workflow scheduled database backups. These backups are stored in [Azure storage accounts](https://portal.azure.com/?feature.msaljs=true#browse/Microsoft.Storage%2FStorageAccounts) and kept for 7 days.

The objectives are:

- Recreate the lost postgres database server
- Restore data from nightly backup stored in Azure

### Start the incident process (if not already in progress)
Follow the [incident playbook](https://tech-docs.teacherservices.cloud/operating-a-service/incident-playbook.html) and contact the relevant stakeholders as described in [create-an-incident-slack-channel-and-inform-the-stakeholders-comms-lead](https://tech-docs.teacherservices.cloud/operating-a-service/incident-playbook.html#4-create-an-incident-slack-channel-and-inform-the-stakeholders-comms-lead).

### Freeze pipeline

Alert developers that no one should merge to main.
- In github setings, a user with repo admin privileges should update the *Branch protection rules* and set required PR approvers to 6

### Enable maintenance mode

Run the *enable maintenance workflow* for the service and environment affected.

The maintenance page message can be [updated](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/maintenance-page.md#update-content) at any time during the incident

### Recreate the lost postgres database server

Run the deploy workflow to recreate the missing postgres database.

As the maintenance page has been enabled, you will need to:
- create a branch from main
- update the terraform application config as per: [configure-terraform-to-keep-deploying-the-application](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/maintenance-page.md#configure-terraform-to-keep-deploying-the-application)
- push the branch to github
- run the deploy workflow using your branch

### Restore the data from previous backup in Azure storage
Run the *restore from backup* workflow.

### Validate app
Confirm the app is working and can see the restored data. The app is available on the [temporary ingress](maintenance-page.md/#fail-over) URL.

### Disable maintenance mode
Run the *disable maintenance workflow* for the service and environment affected.

### Unfreeze pipeline

Alert developers that merge to main is allowed.
- In github settings, update the Branch protection rules and set required PR approvers back to 1

## Scenario 2: [Loss of data](https://technical-guidance.education.gov.uk/infrastructure/disaster-recovery/#data-corruption)

In the case of data loss or corruption, we need to recover the data as soon as possible in order to resume normal service.

The application database is an Azure flexible postgres server. This server has a point-in-time restore (PTR) ability with the resolution of 1 second, available between 5min and 7days. PTR allows you to restore the source server to a point-in-time on a new copy of the server. It does not update the source server itself in any way. Once the new server is available it can be accessed using [konduit.sh](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/scripts/konduit.sh) to check previous data, and data can then be recovered to the original server.

The objectives are:
- Create a separate new postgres database server
- Restore data from the current live database to the new postgres database server from a particular point in time
- Update data into the source database from the new PTR server

### Stop the service as soon as possible
If the service is available, even in a degraded mode, there is a risk users may make edits and corrupt the data even more. Or they might access data they should not have access to. To prevent this, stop the web app and/or workers as soon as possible. This can be completed using the kubectl scale command

e.g. [update namespace and deployment names as required]
- ```kubectl -n bat-staging get deployments```
- ```kubectl -n bat-staging scale deployment itt-mentor-services-staging --replicas 0```
- ```kubectl -n bat-staging scale deployment itt-mentor-services-staging-worker --replicas 0```

### Start the incident process (if not already in progress)
Follow the [incident playbook](https://tech-docs.teacherservices.cloud/operating-a-service/incident-playbook.html) and contact the relevant stakeholders as described in [create-an-incident-slack-channel-and-inform-the-stakeholders-comms-lead](https://tech-docs.teacherservices.cloud/operating-a-service/incident-playbook.html#4-create-an-incident-slack-channel-and-inform-the-stakeholders-comms-lead).

### Freeze pipeline

Alert developers that no one should merge to main.
- In github setings, a user with repo admin privileges should update the *Branch protection rules* and set required PR approvers to 6

### Enable maintenance mode
Run the *enable maintenance workflow* for the service and environment affected.

The maintenance page message can be [updated](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/maintenance-page.md#update-content) at any time during the incident

### Consider backing up the database
If users have entered data or new users have signed up, we may need to keep this data for reconciliation later on. Use the *backup workflow* to save a copy of the flawed database.

### Restore postgres database
Run the point in time restore workflow using a time before the data was deleted.

**Important:** You should convert the time to UTC before actually using it. When you record the time, note what timezone you are using. Especially during BST (British Summer Time).

### Upload restored database to Azure storage
Use the *backup workflow* and choose the restored server as input.

### Restore data into the source server
To perform a complete restore of the source server from the PTR copy, use the *restore workflow* and choose the backup file created above to restore to the live postgres server.

It may be necessary to connect to the source or PTR postgres server for troubleshooting, before deciding on a full restore or otherwise.

To connect to the PTR postgres copy using psql via konduit.
- install konduit locally using make
- ```bin/konduit.sh -x -s name-of-ptr-server name-of-deployment -- psql```

e.g. ```bin/konduit.sh -x -s s189t01-ittms-stg-pg-ptr itt-mentor-services-staging -- psql```

To connect to the existing source postgres server for comparison
- ```bin/konduit.sh -x name-of-deployment -- psql```

e.g. ```bin/konduit.sh -x itt-mentor-services-staging -- psql```

### Validate app
Confirm the app is working and can see the restored data. The app is available on the [temporary ingress](maintenance-page.md/#fail-over) URL.

### Disable maintenance mode
Run the disable maintenance workflow for the service and environment affected

### Unfreeze pipeline

Alert developers that merge to main is allowed.
- In github settings, update the Branch protection rules and set required PR approvers back to 1

### Tidy up
If a PTR was run, the database copy server should be deleted.


If this document is being followed as part of a DR test, then [complete DR test post scenario steps](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/disaster-recovery-testing.md#post-scenario-steps)

## Post DR review
- Schedule an incident retro meeting with all the stakeholders
- Review the incident and fill in the incident report
- Raise trello cards for any process improvements
