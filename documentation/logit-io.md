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
1. Copy beats-SSL endpoint and remove any other input
1. Add beats-SSL endpoint as keyvault secret "BEATS-URL" to the corresponding AKS cluster keyvault
1. [Delete extra indices](#delete-extra-indices)
1. Run terraform-kubernetes-apply for the cluster or clusters
1. Annotate pods with `logit.io/send: "true"` to ship their logs. Use the `enable_logit` variable for applications deployed with the [application module](https://github.com/DFE-Digital/terraform-modules/tree/main/aks/application).
1. [Refresh index pattern](#refresh-index-pattern)

## Logstash inputs
Filebeat sends logs to logstash as json so they can be decoded to create fields in ElasticSearch and query them with Kibana.

We also ask all the applications deployed to the cluster to [log using json output](https://technical-guidance.education.gov.uk/infrastructure/monitoring/logit/#logit-io). The filebeat log contains a field `message` that we decode using the logstash pipeline. And the new fields are stored under the `app` key.

The logstash pipeline is stored here and must be kept up-to-date on all the stacks. It decodes the ingress controller logs so we can observe the HTTP traffic details.

[Standard ECS fields](https://www.elastic.co/guide/en/ecs/current/ecs-field-reference.html) are used as much as possible. This allows a single point of reference, correlation between different event types and reuse of queries and dashbords.

```ruby
filter {
  ### Ingress controller logs ###
  if [kubernetes][deployment][name] == "ingress-nginx-controller" {

    # Container standard out stream
    if [stream] == "stdout" {

      # Decode message field
      grok {
        match => { "message" => ["%{IPORHOST:[source][ip]} - %{DATA:[url][username]} \[%{HTTPDATE:[ingress][time]}\] \"%{WORD:[http][request][method]} %{DATA:[url][original]} HTTP/%{NUMBER:[http][version]}\" %{NUMBER:[http][response][status_code]} %{NUMBER:[http][response][body][bytes]} \"%{DATA:[http][request][referrer]}\" \"%{DATA:[ingress][agent]}\" %{NUMBER:[http][request][bytes]} %{NUMBER:[ingress][request_time]} \[%{DATA:[ingress][proxy][upstream][name]}\] \[%{DATA:[ingress][proxy][alternative_upstream_name]}\] %{NOTSPACE:[ingress][upstream][addr]} %{NUMBER:[ingress][upstream][response][length]} %{NUMBER:[ingress][upstream][response][time]} %{NUMBER:[ingress][upstream][status]} %{NOTSPACE:[http][request][id]}"] }
        # Debug: Comment this line to keep the original message
        remove_field => "message"
      }
      # Use time from ingress access log as log @timestamp
      date {
        match => [ "[ingress][time]", "dd/MMM/YYYY:H:m:s Z" ]
        remove_field => "[ingress][time]"
      }
      # Parse User agent into ECS fields
      useragent {
        source => "[ingress][agent]"
        ecs_compatibility => "v8"
        remove_field => "[ingress][agent]"
      }
      # Use geoip to find location of IP address
      # If the field ends with [ip], the filter will use the parent (here [source]) as a target
      geoip {
        source => "[source][ip]"
        ecs_compatibility => "v8"
      }
    }

    # Container standard error stream
    else if [stream] == "stderr" {

      # Decode message field
      grok {
        match => { "message" => ["%{DATA:[ingress][time]} \[%{DATA:[log][level]}\] %{NUMBER:[ingress][pid]}#%{NUMBER:[ingress][tid]}: (\*%{NUMBER:[ingress][connection_id]} )?%{GREEDYDATA:[ingress][message]}"] }
        # Debug: Comment this line to keep the original message
        remove_field => "message"
      }
      # Use time from ingress error log as log @timestamp
      date {
        match => [ "[ingress][time]", "YYYY/MM/dd H:m:s" ]
        remove_field => "[ingress][time]"
      }
      # Recreate message field
      mutate {
        rename => { "[ingress][message]" => "message" }
      }
    }
  }

  ### Other logs ###
  # If message looks like json, decode it and store under the app key
  else if [message] =~ /^{.*}/  {
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
    # Standardise field names with ECS: https://www.elastic.co/guide/en/ecs/current/index.html
    # Ruby apps log mutate start
    mutate {
      rename => { "[app][payload][status]" => "[http][response][status_code]" }
    }

    mutate {
      rename => { "[app][payload][method]" => "[http][request][method]" }
    }

    mutate {
      rename => { "[app][payload][format]" => "[http][response][mime_type]" }
    }

    mutate {
      rename => { "[app][payload][path]" => "[url][path]" }
    }
   # Ruby apps log mutate end

   # .Net apps log mutate start
    mutate {
      rename => { "[app][Method]" => "[http][request][method]" }
    }

    mutate {
      rename => { "[app][StatusCode]" => "[http][response][status_code]" }
    }

    mutate {
      rename => { "[app][RequestId]" => "[http][request][id]" }
    }

    mutate {
      rename => { "[app][RequestPath]" => "[url][path]" }
    }
    # .Net apps log mutate end
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

## Mapping conflicts
An index mapping is created based on the field types of all the ElastiSearch indices (there is one per day). If a field has a different type in 2 different indices, it creates a mapping conflict and logs may be rejected. Rejected logs will be stored in the [Dead letter queue](https://help.logit.io/en/articles/7891797-logstash-dead-letter-queue-dlq-diagnosing-and-troubleshooting-data-issues-in-opensearch-on-logit-io).

To see which fields are in conflict:
- In kibana, open the left menu
- Select `Dashboards Management`
- Select `Index patterns`
- Select `*-*`
- There will be a warning message. For more details, in the dropdown menu select `conflict` and it will show which fields are in conflict.
- For each one, you can see which index has each type. The first log of the day determines the type of the field for the whole day.

To fix a conflict, make sure the all the logs send the right field types, then delete the indices with the wrong type. Or contact Logit.io support to reindex the logs.

## Delete extra indices
Logs collected by filebeat are stored in daily index `filebeat-<date>`. Other indices may be created with different fields and may cause mapping conflicts.

1. In Kibana, select `Dev Tools` in the left menu
1. List indices: `GET /_cat/indices/`
1. Delete opensearch-sap-log-types-config index: `DELETE /.opensearch-sap-log-types-config`
1. Delete logstash indices: `DELETE /logstash*`
