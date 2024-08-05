# Disaster recovery

The systems are built with resiliency in mind, but they may [fail in different ways](https://technical-guidance.education.gov.uk/infrastructure/disaster-recovery/) and could cause an incident.

This document covers the most critical scenarios and should be used in case of an incident. They should be regularly tested by following the [Disaster recovery testing document](disaster-recovery-testing).

## Scenario 1: [Loss of database server](https://technical-guidance.education.gov.uk/infrastructure/disaster-recovery/#loss-of-database-instance)

In case the database server is lost, the objectives are:

- Recreate the lost postgres database server
- Restore data from nightly backup stored in Azure.

The point-in-time and snapshot backups created by the Azure Postgres service may not be available if it's been deleted, or if there is an Azure region issue.

### Start the incident process
Follow the [incident playbook](https://tech-docs.teacherservices.cloud/operating-a-service/incident-playbook.html) and contact the relevant stakeholders as described in [create-an-incident-slack-channel-and-inform-the-stakeholders-comms-lead](https://tech-docs.teacherservices.cloud/operating-a-service/incident-playbook.html#4-create-an-incident-slack-channel-and-inform-the-stakeholders-comms-lead).

### Enable maintenance mode

Run the *enable maintenance workflow* for the service and environment affected.

### Recreate the lost postgres database server

Run the deploy workflow to recreate the missing postgres database.

As the maintenance page has been enabled, you will need to:
- create a branch from main
- update the env tfvars.json as per: [configure-terraform-to-keep-deploying-the-application](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/maintenance-page.md#configure-terraform-to-keep-deploying-the-application)
- push the branch to github
- run the deploy workflow using your branch

### Restore the data from previous backup in Azure storage
Run the *restore from backup* workflow.

### Validate app
Confirm the app is working and is using the restored data.

### Disable maintenance mode
Run the *disable maintenance workflow* for the service and environment affected.

## Scenario 2: [Loss of data](https://technical-guidance.education.gov.uk/infrastructure/disaster-recovery/#data-corruption)

In the case of data loss or corruption, we need to recover the data as soon as possible in order to resume normal service.

The application's database is an Azure flexible postgres server. This provides a point-in-time restore (PTR) ability with the resolution of 1 second, available between 5min and 7days. PTR allows you to restore the source server to a point-in-time on a new copy of the server, not to the source server itself.

The objectives are:
- Create a separate new postgres database server
- Restore data from the current live database to the new postgres database server from a particular point in time
- Update data into the source database from the new PTR server

### Stop the service as soon as possible
If the service is available, even in a degraded mode, there is a risk users may make edits and corrupt the data even more. Or access data they should not have access to. To prevent this, stop the web app as soon as possible.

### Start the incident process
Follow the [incident playbook](https://tech-docs.teacherservices.cloud/operating-a-service/incident-playbook.html) and contact the relevant stakeholders as described in [create-an-incident-slack-channel-and-inform-the-stakeholders-comms-lead](https://tech-docs.teacherservices.cloud/operating-a-service/incident-playbook.html#4-create-an-incident-slack-channel-and-inform-the-stakeholders-comms-lead).

### Enable maintenance mode
Run the *enable maintenance workflow* for the service and environment affected.

### Consider backing up the database
If users have entered data or new users have signed up, we may need to keep this data for reconciliation later on. Use the *backup workflow* to save a copy of the flawed database.

### Restore postgres database
Run the point in time restore workflow using a time before the data was deleted.

**Important:** You should convert the time to UTC before actually using it. When you record the time, note what timezone you are using. Especially during BST (British Summer Time).

### Upload restored database to Azure storage
Use the *backup workflow* and choose the restored server as input.

### Restore data into the source server
Use the *restore workflow* and choose the backup file created above to restore to the live database server.

### Validate app
Confirm the app is working and can see the restored data. The app is available on the [temporary ingress](maintenance-page#fail-over) URL.

### Disable maintenance mode
Run the disable maintenance workflow for the service and environment affected

### Tidy up
If a PTR was run, the database copy server should be deleted.

## Post DR review
- Schedule an incident retro meeting with all the stakeholders
- Review the incident and fill in the incident report
- Raise trello cards for any process improvements
