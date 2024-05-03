# Shipping application logs to Logit.io

Pod log forwarding to logit.io has been enabled within each cluster.

Filebeat runs in each node, and monitors for pods with the annotation "logit.io/send: true".
Once identified, logs will be sent to the cluster BEATS_URL which is contained in the corresponding cluster key vault.

Services that use terraform-modules can enable logit.io logging by adding "enable_logit: true" to app environments.

Enabling logit via the terraform-module will also disable sending logs to the logs analytics workspace for that environment,
as the module will also add the annotation "fluentbit.io/exclude: true"

## Account
The account "Teacher Services UK" was created by Digital tools support, with the help of the Teacher services finance team to input the payment details.

The UK region must be selected at account creation time as all the ELK stacks created in the account will be in this region, and this cannot be changed later.

## Users
*Digital tools support* adds the users to the account. Request using [the service portal](https://dfe.service-now.com.mcas.ms/serviceportal?id=sc_cat_item&sys_id=45717cc71b02e1904f999978b04bcb61).

## Subscription
We created 3 subscriptions for logs, one for each Azure subscription:
- TEACHER SERVICES CLOUD DEVELOPMENT
    - For testing with dev clusters
    - Plan: cheap plan for testing
- TEACHER SERVICES CLOUD TEST:
    - For the platform-test and test clusters
    - Plan: enough daily volume for the apps on the test cluster, but low retention
- TEACHER SERVICES CLOUD PRODUCTION:
    - For the production cluster
    - Plan: enough daily volume for the apps on the production cluster and 30 days retention

To create a new stack:
1. Discuss the cost with the Teacher services finance team and if required get approval from the deputy director
1. Members of the Administrators team can create a stack
1. Select `ADD STACK`
1. Select the plan
1. Choose monthly billing
1. Rename: `Teacher Services Cloud <Environment>`
1. Add to plan: Logs
1. Set daily volume and retention
1. Click `ADD SUBSCRIPTION`
1. Configure [logstash inputs](#logstash-inputs)
1. Copy beats-SSL endpoint
1. Add beats-SSL endpoint as keyvault secret "BEATS-URL" to the corresponding AKS cluster keyvault
1. Run terraform-kubernetes-apply for the cluster or clusters
1. Annotate pods with `logit.io/send: "true"` to ship their logs. Use the `enable_logit` variable for applications deployed with the [application module](https://github.com/DFE-Digital/terraform-modules/tree/main/aks/application).
1. [Refresh index pattern](#refresh-index-pattern)
1. Test by editing nginx deployment and add annotation to spec/template/metadata/annotations: `logit.io/send: "true"`

## Logstash inputs
Filebeat sends logs to logstash as json so they can be decoded to create fields in ElasticSearch and query them with Kibana.

We also ask all the applications deployed to the cluster to [log using json output](https://technical-guidance.education.gov.uk/infrastructure/monitoring/logit/#logit-io). The filebeat log contains a field `message` that we decode using the logstash pipeline. And the new fields are stored under the `app` key.

The logstash pipeline is stored here and must be kept up-to-date on all the stacks:

```ruby
filter {
  # If message looks like json, decode it and store under the app key
  if [message] =~ /^{.*}/  {
    json {
      source => "message"
      target => "app"
      # Debug: Comment this line to keep the original message
      remove_field => ["message"]
    }

    # Encode HTTP params as json string to avoid indexing thousands of fields
    json_encode {
      source => "[app][payload][params]"
      target => "[app][payload][params_json]"
      # Debug: Comment this line to keep the original object
      remove_field => "[app][payload][params]"
    }
  }
}
```

## Refresh index pattern
When logs are ingested and contain new fields, it may be necessary to refresh the index pattern as non indexed fields cannot be queried. You can see the field is not indexed if there is a warning sign on the log.

1. Go to Kibana (From the dashboard, click `LAUNCH LOGS`)
1. From the left menu select `Dashboards Management`
1. Select `Index patterns`
1. Select `*-*`
1. Click the "Refresh field list" icon
1. The number of fields should change
