# Traefik ingress migration

This document covers the migration plan from nginx ingress to traefik ingress

## Overview

See https://doc.traefik.io/traefik/migrate/nginx-to-traefik/

The Traefik ingress can be installed alongside the current nginx ingress.
Using the kubernetesIngressNGINX provider, it can monitor kubernetes ingress and create the appropraite traefik resources and then takeover the ingress from nginx. No change is required for the existing ingress configuration.

Traefik can monitor and takeover
- a single namespace
    - set watchNamespace: "bat-qa"
- a group of namespaces
    - set watchNamespaceSelector: "traefik-watch=true"
    - then add namespaces to the traefik-watch terraform variable, which will add the label to each one
- all namespaces
    - set neither watchNamespace or watchNamespaceSelector

There are 3 terraform variables for traefik.
All default to false, and will be updated per environment as they are migrated

- add_traefik_ingress_ip, which adds a PIP for traefik
- enable_traefik, which deploys the traefik ingress and associated resources
- add_traefik_to_dns, which adds the ip to the cluster dns

There are also 4 new nginx variables.
- add_nginx_ingress_ip (default true), which adds a PIP for nginx
- enable_nginx (default true), which deploys the nginx ingress and associated resources
- create_nginx_ingressclass (default false), will create a ngnx ingressclass for new clusters that only use traefik
- add_nginx_to_dns (default true) which adds the ip to the cluster dns

## Overall Procedure

Starting with dev, then platform-test, then test and finally production
There will be several weeks of running on test before we migrate production.

Start by copying the cluster/terraform_kubernetes/config/traefik/develpment.values.yaml to a new clusterenv.values.yaml and amend as required.

1. set add_traefik_ingress_ip to true and redeploy
- for test and production, advise service teams in case there are allow lists that need to be updated

2. set enable_traefik to true and redeploy
- use a single namespace initially, set watchNamespace: "traefik"

3. set add_traefik_to_dns to true and redploy

4. enable for extra namespaces
- advise service teams this change will take place
- set watchNamespaceSelector: "traefik-watch=true" and add traefik and monitoring namespaces to traefik-watch
    - remove watchNamespace: "traefik" at the same time
    - redeploy with the above changes
- confirm access to services in these namespaces. There is caching of DNS locally, so you may need to use a private browser window to pick up the traefik ingress.
- add extra namespaces and test e.g. bat-qa.
    - when adding extra namespaces traefik will need to be redeployed or scaled down/up to pick up the changes
    - this step might be skipped for production. tbc

5. check traefik ingress status
- check traffic dashboard
    - kubectl -n traefik port-forward deploy/traefik 8080:8080
    - http://localhost:8080/dashboard/
- check grafana dashboards for traefik
- check traefik access logs in logit, updating logstash as per the development logit stack
- check performance of traefik pods, looking at cpu/memory and restarts
- ask service teams to check services

6. enable for all namespaces
- advise service teams this change will take place
- remove watchNamespaceSelector and watchNamespace and redeploy
- scale nginx-ingress to 0 replicas manually
    - kubectl -n default scale deployment/ingress-nginx-controller --replicas=0
- edit the ingress-nginx-admission webhook and set failurePolicy to Ignore
    - kubectl edit validatingwebhookconfigurations/ingress-nginx-admission
    - otherwise deployments will fail if they try to create an ingress
- if ok, set "ingress_nginx_replicaCount" to 0 and redeploy
    - check the admission webhook hasn't changed back to Fail after redeploy

For production, it might be better to do the below in a single window of 1 or 2 hours
- migrate to traefik out of hours (early morning)
- temporarily adding selected namespaces and monitoring
- then adding all namespaces and complete scale down of nginx
- monitor closely as users start using the services
- it is possible to switch the existing public ip assigned to nginx to traefik if required

## Rollback

At any time, revert back to the nginx-ingress by
- scale up nginx-ingress
    - kubectl -n default scale deployment/ingress-nginx-controller --replicas=10|20
- edit the ingress-nginx-admission webhook and set failurePolicy to Fail
    - kubectl edit validatingwebhookconfigurations/ingress-nginx-admission
- scale down traefik to 0 replicas.
    - kubectl -n traefik scale deployment/traefik --replicas=0

## Post migration

At a later stage the nginx ingress and public IP should be removed entirely.

The current helm chart configuration removes the nginx IngressClass on removal.
Traefik needs this IngressClass to detect and serve Ingress resources that use ingressClassName: nginx.
So when uninstalling NGINX, we need to make sure we keep the kubernetes ingressclass with name nginx and controller k8s.io/ingress-nginx. Dropping the ingressclass for just a short period would result in traefik dropping all the ingress.
Consider adding watchIngressWithoutClass: true once nginx has been removed.
see https://doc.traefik.io/traefik/migrate/nginx-to-traefik/#preserve-the-ingressclass
The nginx helm config will be updated to keep the ingressclass when traefik is enabled.

Removal should also start with development, then platform-test, test, production.

This can be done by settting enable_nginx to false in the terraform config for the target cluster.
It will remove the nginx resources and remove the ip from the cluster DNS.

Note that we set the nginx helm chart to not delete the nginx ingressclass when it's removed.
But that means a new cluster (e.g. development) without nginx will not have the ingressclass.
So a terraform kubernetes_ingress resource will be created if create_nginx_ingressclass is set to true, and this should be the normal setting for development clusters.
If one of the other clusters is recreated after nginx is removed it will also need that parameter set to true.

As mentioned previously consider if switching traefik to the nginx IP and removing the more recent addition is of any benefit.

Steps

1. Remove nginx IP from DNS
    -set add_nginx_to_dns to false
    -It will still be connected to lb while the cache propogates
    -wait a day or two before continuing to the next step

2. Set enable_nginx to false
    - redeploy

3. Set add_nginx_ingress_ip to false.
    - redeploy
