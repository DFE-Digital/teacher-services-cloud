# Disaster Recovery testing

This document covers the Disaster Recovery testing procedure for applications hosted on the Teacher Services AKS clusters based on scenerios details in the [Disaster recovery document](disaster-recovery.md).

## Prerequisites

- Identified environment for the test e.g. qa, staging, test, etc
- Identified scenario(s) that are to be tested
    1. [loss of database instance]((disaster-recovery/#scenario-1-loss-of-database-instance))
    1. [loss of data](disaster-recovery#scenario-2-loss-of-data)
- Repository workflows that should utilise existing DFE github-actions
    - deploy selected env
        - e.g. https://github.com/DFE-Digital/apply-for-teacher-training/blob/main/.github/workflows/deploy-v2.yml
    - backup postgres database to Azure storage [required for scenario 1 above]
        - using https://github.com/DFE-Digital/github-actions/tree/master/backup-postgres
    - restore postgres database from Azure storage [required for scenario 1 above]
        - using https://github.com/DFE-Digital/github-actions/tree/master/restore-postgres-backup
    - point in time restore of postgres database [required for scenario 2 above]
        - using https://github.com/DFE-Digital/github-actions/tree/master/ptr-postgres
- Repo workflows to enable and disable the maintenance page.
    - see https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/maintenance-page.md
    - confirm workflows exists for the selected environment to be tested. Examples;
        - https://github.com/DFE-Digital/apply-for-teacher-training/actions/workflows/enable-maintenance.yml
        - https://github.com/DFE-Digital/apply-for-teacher-training/actions/workflows/disable-maintenance.yml
- Identify the technical and non technical stakeholders who will participate in the test, based on the [Teacher services list](https://educationgovuk.sharepoint.com.mcas.ms/sites/teacher-services-infrastructure/Lists/Teacher%20services%20list/AllItems.aspx)

## Documentation requirements

Copy the [template DR testing document](https://educationgovuk.sharepoint.com/:w:/r/sites/TeacherServices/Shared%20Documents/DR%20tests/DR%20test%20template.docx?d=waba054c48ee644e5ab5a66c784fa3b95&csf=1&web=1&e=CRNjv7) which will be a record of the scenarios run, time taken, and any issues.

## Initial set-up

Participants must have access to Github and the repositories.

Schedule virtual meeting for the test to take place
- teams or slack
- invite the relevant stakeholders

Regularly provide updates on the service Slack channel to keep product owners abreast of developments.

## Freeze pipeline

Alert developers that no one should merge to main.
- In github setings, a user with repo admin privileges should update the *Branch protection rules* and set required PR approvers to 6

## Scenario 1: Loss of database instance
See [DR scenario 1](disaster-recovery/#scenario-1-loss-of-database-instance).

### Delete the postgres database instance

Note that you must have a previously created backup on azure storage before starting this step. If not, create one now before continuing.

- Delete the existing postgres database
    - manually delete via UI https://portal.azure.com/#browse/Microsoft.DBforPostgreSQL%2FflexibleServers
- Confirm it's deleted

Follow the disaster recovery instructions.

## Scenario 2: Loss of data
See [DR scenario 2](disaster-recovery#scenario-2-loss-of-data).

### Delete data from the postgres database instance

Make a note of the time this step is being started as the restore point must be before you delete any data.

- Delete a table manually
    - connect via konduit and delete the table
    - it must be possible to confirm the data has been deleted either within the app, by errors messages being logged, the app crashing or users observing inconsistent content.

Follow the disaster recovery instructions.

## Post scenario steps

### Unfreeze pipeline

Alert developers that merge to main is allowed.
- In github settings, update the Branch protection rules and set required PR approvers back to 1

### Documentation requirements

- Complete the DR testing document and save in the [DR test Reports folder](https://educationgovuk.sharepoint.com/:f:/r/sites/TeacherServices/Shared%20Documents/DR%20tests/Reports?csf=1&web=1&e=DyDQqy)
- Update the service on the infra team sharepoint service list with the DR date and status (success/fail)

## Post DR test review
- Review the just completed DR test, and raise trello cards for any process improvements.
- Review the contact list in the [Teacher services list](https://educationgovuk.sharepoint.com.mcas.ms/sites/teacher-services-infrastructure/Lists/Teacher%20services%20list/AllItems.aspx)
