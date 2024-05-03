# Log Analytics

Each cluster sends diagnostic log data to a cluster log analytics workspace.
This can generate a lot of data, at a high cost, so we override some of the default settings.

We have added two settings to ama-logs via config map.
- Remove env vars from each ContainerInventory entry as it adds a lot of data that's not particularly useful
    - log_collection_settings.env_var = false
- Allow exclude of log collection from pods with annotations fluentbit.io/exclude: "true".
    - log_collection_settings.filter_using_annotations = true

The config map must be called container-azm-ms-agentconfig.
The ama-logs daemonset has an optional mount for this map, and if one is loaded to the cluster it will automatically mount and restart any ama-logs pods with the new settings.
see https://github.com/microsoft/Docker-Provider/blob/ci_prod/kubernetes/container-azm-ms-agentconfig.yaml for available variables and default settings.

# Retrieving Log Analytics Data with KQL for AKS Clusters

Kusto Query Language (KQL) is a query language that you can use to retrieve data from Log Analytics workspaces for Azure Kubernetes Service (AKS) clusters. In this guide, we will explain how to write KQL queries to retrieve Log Analytics data and analyze it for your AKS cluster.

N.B. please allow around 15 mins for the logs to be generated and ingested into the log analytics workspace

## Writing KQL Queries

To write a KQL query to retrieve AKS Log Analytics data, follow these steps:

1. Open the Azure portal and navigate to your resource group where the cluster is deployed.

2. Navigate to the AKS instance, then “Logs” under the “Monitoring” section of the blade on the left of the AKS cluster on the portal. Click on the Log Analytics Workspace link.

3. In the query editor, you can start typing your KQL query. For example, you might want to retrieve all control plane logs from the last 24 hours:

    ```
    AzureDiagnostics
    | where Category == "kube-apiserver"
    | where TimeGenerated >= ago(24h)
    ```

4. Press the "Run" button to execute the query.

5. The results of the query will be displayed in the "Results" tab. You can further refine and analyze the data using the tools in the query editor.

## Query Examples

Here are some examples of KQL queries that you can use to retrieve AKS Log Analytics data:

- Retrieve all container inventory with the state terminated:

    ```
    ContainerInventory
    | where ContainerState == "Terminated"
    | project Computer, Name, Image, ImageTag, ContainerState, CreatedTime, StartedTime, FinishedTime
    | render table

    ```

- Retrieve all admin audit logs:

    ```
    AzureDiagnostics
    | where Category == "kube-audit-admin"
    ```

These are just a few examples of the many queries that you can write using KQL to retrieve AKS Log Analytics data.
