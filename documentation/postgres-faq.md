# Postgres FAQ

FAQ for anything postgres related

## Admin password change

The Postgres admin user and password is created by the postgres terraform module.

https://github.com/DFE-Digital/terraform-modules/tree/main/aks/postgres

If you need to change the password for any reason, then use the following procedure which will trigger a new password on the next deployment.
Note that make commands and directories may be slightly different for your service, so check within your Makefile before running.

This example changes the postgres admin password for the development env of the service

1. Set terraform env
```shell
$ make development terraform-init
```

2. Get the password resource (chdir directory may be different for your service)
```shell
$ terraform -chdir=terraform/aks state list |grep random_password
module.postgres.random_password.password[0]
```

3. Taint the password resource so it will be regenerated on next terraform apply
```shell
$ terraform -chdir=terraform/aks taint module.postgres.random_password.password[0]
```

4. Terraform plan should show that the password will be recreated on next run, alongside updates to application secrets and app deployments (due to a change to the DATABASE_URL).
```shell
$ make development terraform-plan

...
  # module.postgres.random_password.password[0] is tainted, so must be replaced
-/+ resource "random_password" "password" {
      ~ bcrypt_hash = (sensitive value)
      ~ id          = "none" -> (known after apply)
      ~ result      = (sensitive value)
        # (10 unchanged attributes hidden)
    }
...
```

## Monitor performance
When [monitoring](https://github.com/DFE-Digital/terraform-modules/blob/6278cbb72bfcf614e6f1572f5f5380a3543f5924/aks/postgres/variables.tf#L115) is enabled, metrics and logs are available in the *Monitoring* section of the pogres server portal page.

Active queries are listed in the `pg_stat_activity` table and it should be cheked first. Use [konduit](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/scripts/konduit.sh) to connect.

Azure offers more tools for helping analysing the database performance. They can be useful in case of slowness or high resource usage.

Take note of the customisations and remove them when they're not needed anymore. Also, if you run terraform, it may discard all the manual changes.

### Enable server parameters
- [metrics.collector_database_activity](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-monitoring#enabling-enhanced-metrics): capture enhanced metrics related to Activity, Database, Logical replication, Replication, Saturation, Traffic
- [metrics.autovacuum_diagnostics](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-monitoring#autovacuum-metrics): capture metrics related to the [postgres autovacuum process](https://www.postgresql.org/docs/14/routine-vacuuming.html)
- [pg_qs.query_capture_mode](https://learn.microsoft.com/en-us/azure/postgresql/single-server/concepts-query-store-best-practices#set-the-optimal-query-capture-mode): Set to *All* (performance impact) or *Top* to analyse queries in the query store
- [pgms_wait_sampling.query_capture_mode](https://learn.microsoft.com/en-us/azure/postgresql/single-server/concepts-query-store-best-practices#set-the-optimal-query-capture-mode): set to *all* to capture wait statistics in the query store
- [track_io_timing](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-high-io-utilization#the-pg_stat_statements-extension): IO metrics, required for troubleshooting

### Send metrics to Log analytics
By default only logs are stored in the Log analytics workspace. Storing metrics is required for troubleshooting.

1. Navigate to Monitoring > Diagnostic settings
1. Edit the existing setting
1. Tick `AllMetrics` and click `Save`

### Analyse
After 15-30min, these tools can now be used:
- Intelligent Performance > Query performance impact
- Help > Troubleshooting guides
- Monitoring > Workbooks
- The query store is available in the `azure_sys` database on the same server
