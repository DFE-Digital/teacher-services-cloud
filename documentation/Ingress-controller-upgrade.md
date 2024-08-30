# Ingress Controller Upgrade

**Pre-requisites**
- AKS Cluster with the ingress controller you wish to upgrade.
- In test you can use the welcome app for monitoring.
- Set your AKS context for the cluster i.e. `make test get-cluster-credentials CONFIRM_TEST=yes` [Follow Main Readme.md](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/README.md)

## Monitoring the upgrade
- Start the monitoring in a separate window using curl. This will monitor any app downtime please open a new window or terminal session for this and monitor the below url.
  ```
  while true; do date; curl -si https://test.teacherservices.cloud/ | grep HTTP; sleep 1; done
  ```
- Please open a new window or terminal session for this.
  ```
  kubectl get pods -n default -w
  ```
## Upgrade

- To start the upgrade open the file `test.tfvars.json` located at `cluster/terraform_kubernetes/config`
- This is an oportunity to test changes in test cluster before rolling out to higher environment like prod
- Set the value of the variable i.e. `"ingress_nginx_version": "4.8.3"`
- Run terraform apply

```
make test terraform-apply CONFIRM_TEST=yes
```
- At this point monitor your cluster as well as curl response and make sure it returns and cycle `200` .
- You will also see the pod recreated through its life cycle below:

        ```
        ingress-nginx-admission-create-kksm2        0/1     Pending   0          0s
        ingress-nginx-admission-create-kksm2        0/1     ContainerCreating   0          0s
        ingress-nginx-admission-create-kksm2        1/1     Running             0          3s
        ingress-nginx-admission-create-kksm2        0/1     Completed           0          4s


        ```
- Follow the same process for production and raise a PR for each environment.
- Wait at least 24 hours before applying upgrade to production (if any downtime was obversed during deployment(s) to lower environment(s), notify the application teams before production upgrade).
