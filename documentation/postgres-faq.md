# Postgres FAQ

FAQ for anything postgres related

## Admin password change

The Postgres admin user and password is created by the postgres terraform module.

https://github.com/DFE-Digital/terraform-modules/tree/main/aks/postgres

If you need to change the password for any reason, then use the following procedure which will trigger a new password on the next deployment.
Note that make commands and directories may be slightly different for your service, so check within your Makefile before running.

This example changes the postgres admin password for the development env of the service

1. Set terraform env
```
$ make development terraform-init
```

2. Get the password resource (chdir directory may be different for your service)
```
$ terraform -chdir=terraform/aks state list |grep random_password
module.postgres.random_password.password[0]
```

3. Taint the password resource so it will be regenerated on next terraform apply
```
$ terraform -chdir=terraform/aks taint module.postgres.random_password.password[0]
```

4. Terraform plan should show that the password will be recreated on next run, alongside updates to application secrets and app deployments (due to a change to the DATABASE_URL).
```
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
