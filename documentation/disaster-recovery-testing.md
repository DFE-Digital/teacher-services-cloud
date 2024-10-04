# Disaster Recovery testing

This document covers the Disaster Recovery testing procedure for applications hosted on the Teacher Services AKS clusters based on scenarios detailed in the [Disaster recovery document](disaster-recovery.md).

## Prerequisites

- Identified environment for the test e.g. qa, staging, test, etc
- Identified scenario(s) that are to be tested
    1. [loss of database instance](disaster-recovery.md/#scenario-1-loss-of-database-server)
    1. [loss of data](disaster-recovery.md/#scenario-2-loss-of-data)
- Repository workflows that should utilise existing DFE github-actions
    - Deploy selected env
        - e.g. https://github.com/DFE-Digital/apply-for-teacher-training/blob/main/.github/workflows/deploy-v2.yml
    - *Backup postgres database to Azure storage* [required for scenario 1 above]
        - using https://github.com/DFE-Digital/github-actions/tree/master/backup-postgres
    - *Restore database from Azure storage* [required for scenario 1 above]
        - using https://github.com/DFE-Digital/github-actions/tree/master/restore-postgres-backup
    - *Restore database from point in time to new database server* [required for scenario 2 above]
        - using https://github.com/DFE-Digital/github-actions/tree/master/ptr-postgres
- Repo workflows to enable and disable the maintenance page.
    - see https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/maintenance-page.md
    - confirm workflows exists for the selected environment to be tested. Examples:
        - https://github.com/DFE-Digital/apply-for-teacher-training/actions/workflows/enable-maintenance.yml
        - https://github.com/DFE-Digital/apply-for-teacher-training/actions/workflows/disable-maintenance.yml
- an app url that identifies the current docker image sha. Can be part of the healthcheck e.g. https://github.com/sdglhm/okcomputer/blob/master/lib/ok_computer/built_in_checks/app_version_check.rb
- Identify the technical and non technical stakeholders who will participate in the test, based on the [Teacher services list](https://educationgovuk.sharepoint.com.mcas.ms/sites/teacher-services-infrastructure/Lists/Teacher%20services%20list/AllItems.aspx)

## Documentation requirements

Copy the [template DR testing document](https://educationgovuk.sharepoint.com/:w:/r/sites/TeacherServices/Shared%20Documents/DR%20tests/DR%20test%20template.docx?d=waba054c48ee644e5ab5a66c784fa3b95&csf=1&web=1&e=CRNjv7) which will be a record of the scenarios run, time taken, and any issues.

## Initial set-up

Participants must have access to Github and the repositories.

Schedule virtual meeting for the test to take place
- teams or slack
- invite the relevant stakeholders

Regularly provide updates on the service Slack channel to keep product owners abreast of developments.

## Scenario 1: Loss of database instance
See [DR scenario 1](disaster-recovery.md/#scenario-1-loss-of-database-server).

### Delete the postgres database instance

Note that you must have a previously created backup on azure storage before starting this step. If not, create one now before continuing.

- Delete the existing postgres database
    - manually delete via UI https://portal.azure.com/#browse/Microsoft.DBforPostgreSQL%2FflexibleServers
- Confirm it's deleted
- Check and delete any postgres diagnostics remaining for the deleted instance in https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/diagnosticsLogs as the later deploy to rebuild postgres will fail if it remains. e.g. s189t01-ittms-stg-pg-diagnotics

Follow the disaster recovery instructions.

## Scenario 2: Loss of data
See [DR scenario 2](disaster-recovery.md#scenario-2-loss-of-data).

### Delete data from the postgres database instance

Make a note of the time this step is being started as the restore point must be before you delete any data.

- Delete a table manually
    - connect via konduit and delete the table
    - it must be possible to confirm the data has been deleted either within the app, by errors messages being logged, the app crashing or users observing inconsistent content.

Follow the disaster recovery instructions.

## Post scenario steps

### Documentation requirements

- Complete the DR testing document and save in the [DR test Reports folder](https://educationgovuk.sharepoint.com/:f:/r/sites/TeacherServices/Shared%20Documents/DR%20tests/Reports?csf=1&web=1&e=DyDQqy)
- Update the service on the infra team sharepoint service list with the DR date and status (success/fail)

## Post DR test review
- Review the just completed DR test, and raise trello cards for any process improvements.
- Review the contact list in the [Teacher services list](https://educationgovuk.sharepoint.com.mcas.ms/sites/teacher-services-infrastructure/Lists/Teacher%20services%20list/AllItems.aspx)
