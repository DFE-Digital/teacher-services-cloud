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

There are 3 terraform variables.
All default to false, and will be updated per environment as they are migrated

- add_traefik_ingress_ip, which adds a PIP for traefik
- enable_traefik, which deploys the traefik ingress and associated resources
- add_traefik_to_dns, which adds the ip to the cluster dns

## Overall Procedure

Starting with dev, then platform-test, then test and finally production
There will be several weeks of running on test before we migrate production.

1. set add_traefik_ingress_ip to true
- for test and production, advise service teams in case there are allow lists that need to be updated

2. set enable_traefik to true
- use a single namespace initially, set watchNamespace: "traefik"

3. set add_traefik_to_dns to true

4. enable for extra namespaces
- advise service teams this change will take place
- set watchNamespaceSelector: "traefik-watch=true" and add traefik and monitoring namespaces to traefik-watch
    - remove watchNamespace: "traefik" at the same time
- confirm access to services in these namespaces. There is caching of DNS locally, so you may need to use a private browser window to pick up the traefik ingress.
- add extra namespaces and test e.g. bat-qa.
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
- remove watchNamespaceSelector and watchNamespace
- scale nginx-ingress to 0 replicas manually
- edit the ingress-nginx-admission webhook and set failurePolicy to Ignore
    - kubectl edit validatingwebhookconfigurations/ingress-nginx-admission
    - otherwise deployments will fail if they try to create an ingress
- if ok, set "ingress_nginx_replicaCount" to 0

For production, it might be better to do the below in a single window of 1 or 2 hours (tbc)
- migrate to traefik out of hours (early morning)
- temporarily adding selected namespaces and monitoring
- then adding all namespaces and complete scale down of nginx
- monitor closely as users start using the services
- it is possible to switch the existing public ip assigned to nginx to traefik if required

## Rollback

At any time, revert back to the nginx-ingress by
- scale up nginx-ingress
- edit the ingress-nginx-admission webhook and set failurePolicy to Fail
    - kubectl edit validatingwebhookconfigurations/ingress-nginx-admission
- scale down traefik to 0 replicas.

## Post migration

At a later stage the nginx ingress and public IP should be removed entirely, but the helm chart removes the nginx IngressClass. Traefik needs this IngressClass to detect and serve Ingress resources that use ingressClassName: nginx.
So when uninstalling NGINX, make sure you keep or create a kubernetes ingressclass with name nginx and controller k8s.io/ingress-nginx.
see https://doc.traefik.io/traefik/migrate/nginx-to-traefik/#preserve-the-ingressclass
Removal should also start with development, then platform-test, test, production.

Also remove the public IP. As mentioned previously consider if switching traefik to the nginx IP and removing the more recent addition is of any benefit.
