# Monitoring

Details for any cluster or subscription monitoring

## Subscription monitoring

Manually created service health alerts for each s189 subscription.

s189[d|t|p]-service-health-alert

They will trigger on the below events for UK South or Global regions, and send an email to the TS infra team
- service issue
- planned maintenance
- health advisories
- security advisory

## Cluster statuscake alerts

Terraform created statuscake monitoring for the permanent clusters.

These monitor https://status.${cluster}/healthz for each cluster,
and will email and page the TS infra team on failure.
