# Traefik ingress migration

This document covers the migration plan from nginx ingress to traefik ingress

## Overview

See https://doc.traefik.io/traefik/migrate/nginx-to-traefik/

The Traefik ingress can be installed alongside the current nginx ingress.
Using the kubernetesIngressNGINX provider, it can monitor kubernetes ingress and create the appropriate traefik resources and then takeover the ingress from nginx. No change is required for the existing ingress configuration.

Traefik can monitor and takeover
- a single namespace
    - set watchNamespace: "bat-qa"
- a group of namespaces
    - set watchNamespaceSelector: "traefik-watch=true"
    - then add namespaces to the traefik-watch terraform variable, which will add the label to each one
- all namespaces
    - set neither watchNamespace or watchNamespaceSelector
- note that when monitoring selected namespaces, there will be failures if the traefik IP is added to the load balancer, as traefik will receive requests for ingress it doesn't have any config for i.e. namespaces that aren't being monitored

There are 3 terraform variables for traefik.
All default to false, and will be updated per environment as they are migrated

- add_traefik_ingress_ip, which adds a PIP for traefik
- enable_traefik, which deploys the traefik ingress and associated resources
- add_traefik_to_dns, which adds the ip to the cluster dns (for dev only)

There are also 4 new nginx variables.
- add_nginx_ingress_ip (default true), which adds a PIP for nginx
- enable_nginx (default true), which deploys the nginx ingress and associated resources
- create_nginx_ingressclass (default false), will create a ngnx ingressclass for new clusters that only use traefik
- add_nginx_to_dns (default true) which adds the ip to the cluster dns (for dev only)

## Overall Procedure

Starting with dev, then platform-test, then test and finally production.
There will be several weeks of running on test before we migrate production.

Start by copying the cluster/terraform_kubernetes/config/traefik/development.values.yaml to a new clusterenv.values.yaml and amend as required.

1. create traefik PIP
- set add_traefik_ingress_ip to true
- for test and production, advise service teams of the new IP in case there are allow lists that need to be updated (this shouldn't be the case).

2. deploy traefik for all ingress, but with publishService disabled

Traefik will be installed, but will not service any requests as it has not been added to the load balancer, and does not control any ingress
- set enable_traefik to true
- remove watchNamespaceSelector and watchNamespace (so all namespaces monitored)
- set publishService to false

Once deployed
- check the traefik dashboard and make sure all ingress have been created
- check traefik logs to confirm all looks ok and there aren't any errors
- check traefik pod cpu and memory use

3. Add traefik to the loadbalancer

Traefik and nginx can both serve incoming requests, depending on which IP is used.
- for development, set add_traefik_to_dns to true and redeploy
- for other clusters, update the A record in custom_domains/terraform/infrastructure/config/production.tfvars.json
- this will need to be temporarily removed from cicd as the code doesn't work with two addresses
- for test and prod advise services to let the devops team know if they see any request errors or issues

Monitor ingress
- check traffic dashboard
    - kubectl -n traefik port-forward deploy/traefik 8080:8080
    - http://localhost:8080/dashboard/
- check grafana dashboards for traefik
- check traefik access logs in logit, updating logstash as per the development logit stack
- check performance of traefik pods, looking at cpu/memory and restarts
- ask service teams to check services

4. Remove nginx from the load balancer

Nginx Ingress will still be deployed and active, but ingress will only be served by Traefik once the DNS change has propagated
- for development, set add_nginx_to_dns to false
- for other clusters, update the A record in custom_domains/terraform/infrastructure/config/production.tfvars.json

Monitor ingress
- check traffic dashboard
    - kubectl -n traefik port-forward deploy/traefik 8080:8080
    - http://localhost:8080/dashboard/
- check grafana dashboards for traefik
- check traefik access logs in logit, updating logstash as per the development logit stack
- check performance of traefik pods, looking at cpu/memory and restarts
- ask service teams to check services

5. Shutdown nginx

Wait 24-48 hours after removing nginx from the load balancer in step 4, and confirming that the logs show nginx is no longer servicing any requests.
- set "ingress_nginx_replicaCount" to 0
    - this can also be scaled manually before deploy
    - kubectl -n default scale deployment/ingress-nginx-controller --replicas=0
- edit the ingress-nginx-admission webhook and set failurePolicy to Ignore, otherwise deployments will fail if they try to create an ingress
    - kubectl edit validatingwebhookconfigurations/ingress-nginx-admission
    - Note: check the admission webhook hasn't changed back to Fail after any redeploy

Monitor ingress
- check traffic dashboard
    - kubectl -n traefik port-forward deploy/traefik 8080:8080
    - http://localhost:8080/dashboard/
- check grafana dashboards for traefik
- check traefik access logs in logit, updating logstash as per the development logit stack
- check performance of traefik pods, looking at cpu/memory and restarts
- ask service teams to check services

## Rollback

At any time and depending on the current configuration
Restart nginx
- recreating an nginx pip if this was deleted
- redeploying or scale up of the nginx-ingress
    - kubectl -n default scale deployment/ingress-nginx-controller --replicas=10|20
- edit the ingress-nginx-admission webhook and set failurePolicy to Fail
    - kubectl edit validatingwebhookconfigurations/ingress-nginx-admission
- adding the nginx ip to the load balancer

Disable traefik
- remove traefik ip from the load balancer
- scale down traefik to 0 replicas.
    - kubectl -n traefik scale deployment/traefik --replicas=0

## Post migration

The nginx ingress and public IP should be removed entirely.
This can be done by
- setting enable_nginx to false
- set add_nginx_to_dns to false (for dev)
- for other clusters, remove the A record in custom_domains/terraform/infrastructure/config/production.tfvars.json
which will remove the nginx resources and remove the nginx pip.

Note that if unchanged, the helm chart would delete the nginx IngressClass on removal. Dropping the ingressclass for just a short period would result in traefik dropping all the ingress, and the complete loss of service.
To stop this occurring, the nginx helm config will be updated to keep the ingressclass if traefik is enabled when enable_traefik is set to true.
Consider adding watchIngressWithoutClass: true once nginx has been removed.
see https://doc.traefik.io/traefik/migrate/nginx-to-traefik/#preserve-the-ingressclass


As we set the nginx helm chart to not delete the nginx ingressclass when it's removed, this means a new cluster (e.g. development) without nginx will not have the ingressclass.
So a terraform kubernetes_ingress resource will be created if create_nginx_ingressclass is set to true, and this should be the normal setting for development clusters only.
If one of the other clusters is recreated after nginx is removed it will also need that parameter set to true.
