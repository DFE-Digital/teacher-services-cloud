## Developer onboarding

Documentation for the Teacher services application developers

NOTE: For additional info about infrastructure see [
Sharepoint: Teacher services infrastructure](https://educationgovuk.sharepoint.com.mcas.ms/sites/teacher-services-infrastructure). Also make sure to review the [technical guidance](https://technical-guidance.education.gov.uk/) and especially [Data Protection Considerations](https://technical-guidance.education.gov.uk/standards/storing-source-code/#data-protection-considerations-git-repositories).

## Software requirements
- OS: Linux, MacOS or Windows with WSL
- [azure cli](https://technical-guidance.education.gov.uk/infrastructure/dev-tools/#azure-cli)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [terraform](https://technical-guidance.education.gov.uk/infrastructure/dev-tools/#installation)
- [jq](https://stedolan.github.io/jq/)
- [kubelogin](https://azure.github.io/kubelogin/install.html)

## How to request access?
- There is an assumption that you have been given a [CIP account](https://technical-guidance.education.gov.uk/infrastructure/hosting/azure-cip/#onboarding-users). For BYOD users, please make sure to request a [digitalauth account](https://educationgovuk.sharepoint.com/sites/teacher-services-infrastructure/SitePages/Request-a-digitalauth-Azure-account.aspx).
- It is recommended to set up 2FA with the Microsoft authenticator app as it provides useful notifications. Also, set up a backup 2FA using your phone for text messages.
- BYOD users will have 2 2FA challenges, one for digital, one for DFE Platform identity
- The technical lead of your team will then add you to the AD group of your area. For example if you work on a BAT service, you will be added to "s189 BAT delivery team". You will now be able to:
   - Access (read-only) the s189 subscriptions in the [Azure portal](https://portal.azure.com/#home)
   - Access (read-write) to your test Kubernetes namespaces and Azure resource groups in the _test_ subscription
   - [Elevate your permissions via PIM](#how-to-request-and-approve-pim) and access (read-write) temporarily the production Kubernetes namespaces and Azure resource groups
   - Approve other developers' PIM requests

## How to reset 2FA
- BYOD should try to identify which 2FA is failing (digital or DfE Platform identity), as the team needs to know which one to reset
- Raise a [Service now CIP request](https://dfe.service-now.com.mcas.ms/ithelpcentre?id=sc_cat_item&sys_id=51b0b9c5db1ff7809402e1aa4b96197d&referrer=recent_items) and choose Azure Cloud General Request

## How to request PIM?
Microsoft Entra Privileged Identity Management (PIM) allows gaining temporary (up to 8h) user permissions to access production resources. This is sometimes required to access the Kubernetes cluster and troubleshoot the application or database.

- Use [PIM for groups](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/groups-activate-roles) to elevate your access. You should see the PIM group of your area. For example if you work on a BAT service, you should see: "s189 BAT production PIM".
- Click "Activate", select the time and give a brief justification, which is important to gain approval and audit purpose.
- The other members of the team will receive an email with a link to PIM so they can review and approve your request.
- After a few minutes, your access will be active. It may require login out and in again.

## Accessing Azure Portal
- When Access the [Azure portal](https://portal.azure.com/#home) make sure you switch to your digitalauth account and switch directory to DfE Platform Identity.

## Which clusters can I use?
The infra team maintains several AKS clusters. Two are usable by developers to deploy their services:

### Test cluster
Used for all your non-production environments: review, development, qa, staging...
- Name: `s189t01-tsc-test-aks`
- Resource group: `s189t01-tsc-ts-rg`
- Subscription: `s189-teacher-services-cloud-test`

### Production cluster
Used for all your production and production-like environments, especially if they contain production data: production, pre-production, production-data...
- Name: `s189p01-tsc-production-aks`
- Resource group: `s189p01-tsc-pd-rg`
- Subscription: `s189-teacher-services-cloud-production`

## How to access the cluster?
- If not present in your repository, set up the `get-cluster-credentials` make command from the template [Makefile](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/templates/new_service/Makefile).
- If the environment is production, raise a [PIM request](#how-to-request-pim)
- Login to azure command line using `az login` or `az login --use-device-code`
- Run `make <environment> get-cluster-credentials`
- This configures the `kubectl` context so you can run commands against this cluster
- *NOTE:* If problems running `az login` make sure you have accessed the Azure Portal as above first. Also run `az logout` before running `az login`.

## What is a namespace?
Namespaces are a way to logically partition and isolate resources within a Kubernetes cluster. Each namespace has its own set of isolated resources like pods, services, deployments etc.
By default, a Kubernetes cluster will have a few initial namespaces created like "default", "kube-system", "kube-public" etc. We have created specific namespaces per area, such as "BAT" or "TRA".
For instance, you will see:

- *tra-development* and *tra-staging* on the test cluster
- *tra-production* on the production cluster

Here is the full list of namespaces [in the test cluster](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/cluster/terraform_kubernetes/config/test.tfvars.json) and [in the production cluster](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/cluster/terraform_kubernetes/config/production.tfvars.json).

*kubectl* commands run in a particular namespace using `-n <namespace>`.

## Basic commands
First [get access](#how-to-access-the-cluster) to the desired cluster. Then you can run commands using kubectl against different kubernetes resources.

### Deployment
Allows you to specify the desired state of your application. It allows you to deploy multiple pods and services and manage them as a single entity. It also allows you to do rolling updates and rollbacks.

Examples kubectl deployment usage:
- List deployments in a namespace: `kubectl -n <namespace> get deployments`
- Get configuration and status: `kubectl -n <namespace> describe deployment <deployment-name>`
- Scale deployment horizontally: `kubectl -n <namespace> scale deployment <deployment-name> --replicas=3`

### Pod
Each deployment runs 1 or more instances of the application to scale horizontally. Each one runs in a pod, which is ephemeral and can be deleted or recreated at any time. Deployments provide a way to keep pods running and provide a way to update them when needed.

Examples kubectl pod usage:
- List pods in a namespace: `kubectl -n <namespace> get pods`
- Get pod configuration and status: `kubectl -n <namespace> describe pod <pod-name>`
- Get pod logs: `kubectl -n <namespace> logs <pod-name>`
- Get logs from the first pod in the deployment: `kubectl -n <namespace> logs deployment/<deployment-name>`
- Stream logs from all pods in the deployment: `kubectl -n <namespace> logs -l app=<deployment-name> -f`
- Display CPU and memory usage: `kubectl -n <namespace> top pods`
- Execute a command inside a pod: `kubectl -n <namespace> exec <pod-name> -- <command>`
- Execute a command inside the first pod in the deployment:
   ```
   kubectl -n <namespace> exec deployment/<deployment-name> -- <command>
   ```
- Open an interactive shell inside a pod: `kubectl -n <namespace> exec -ti <pod-name> -- sh`

### Ingress controller
All HTTP requests enter the cluster via the ingress controller. Then it sends them to the relevant pods. We can observe the HTTP traffic to a particular deployment.

- Deployment filter: `<namespace>-<deployment-name>-80` e.g. `bat-qa-register-qa-80`
- Stream logs from all ingress controllers and filter on the deployment:
   ```
   kubectl logs -l app.kubernetes.io/name=ingress-nginx -f --max-log-requests 20 | grep <deployment-filter>
   ```

## Logging
Application logs are [sent to Logit.io](production-checklist#logging). They are ingested, decoded and stored. Users can then query the logs, create dashboards, create alerts...

### Access
Request access using the [Logit Service Now form](https://dfe.service-now.com/ithelpcentre?id=sc_cat_item&table=sc_cat_item&sys_id=45717cc71b02e1904f999978b04bcb61). Choose Teacher services UK organisation, and all stacks.

### Discover
There are 2 important stacks: one for the test cluster, and one for the production cluster. Choose the one corresponding to your application environment and click *LAUNCH LOGS*. This opens [Kibana](https://www.elastic.co/kibana).

- Filter by `kubernetes.deployment.name` to select your application logs
- The HTTP logs are in the ingress-nginx-controller deployment name. Filter again by `ingress.proxy.upstream.name` to select your web application HTTP logs.

You can add more filters, use the full [DQL](https://opensearch.org/docs/latest/dashboards/dql/) language, refine the time range, select fields to display... [Explore](https://www.elastic.co/guide/en/kibana/current/discover.html). And you can create [visualizations and dashboards](https://www.elastic.co/guide/en/kibana/current/dashboard.html).

Application logs should be [sent as json](production-checklist#logging), as they are decoded automatically so that individual fields can be used in filters and queries. All app fields are stored under the `app` field.

### Warnings
- Developers should pay attention not to send any personal data. It must be removed or obfuscated.
- The stacks are shared for all services. It is important not to send too many logs as it may exceed our quota
- In case of issue, contact the infra team who can add temporary fixes [using Logstash](logit-io#logstash-inputs)

## Monitoring
The main monitoring tools used are Grafana and Alertmanager. For further reading about Monitoring setup in the cluster [click here](https://github.com/DFE-Digital/teacher-services-cloud/blob/97a19da1aedf604e7778b25ce747fd9a9a61a670/documentation/monitoring.md).

### Grafana
Grafana could be accessed via the respective URLs based on the environment of interest. The URLs corresponding to each environment as below:

* Test | https://grafana.test.teacherservices.cloud
* Production | https://grafana.teacherservices.cloud/

The default access to the grafana interface is view only, which does not require authentication. In order to be able to make changes for example adding more dashboards and editing existing dashboards, requests will have to be made in the #teacher-services-infra slack channel to obtain admin credentials.

### Exporting a Grafana Dashboard as json
Grafana allows you to export your dashboard as a JSON file, which can be version controlled and shared with others. This could be achieved by following these steps:
- 	Open your dashboard in Grafana
-	Click on the "Share" button(icon) in the top left corner
-	In the "Export" tab, select "Export for sharing externally"
-	Click "Save to file" to download the JSON file of your dashboard

### Editing or creating new grafana dashboards
The following steps are required for creating or editing dashboards. Please [click](https://grafana.com/docs/grafana/latest/fundamentals/dashboards-overview/) for more extensive details
-   Ensure you are logged in as an admin
-   Identify the purpose of your dashboard. What insights the dashboard will provide and what messages it  conveys
- 	Plan and Design how the dashboard would look when completed, paying attention to the placement of panels, alignment, spacing, colour
    and organisation
- 	Select the Appropriate Data Sources by identifying the right datasource to visualise in the dashboard (currently prometheus is the only
   datasource available to select )
-  Click on the "Explore" view, select the datasource(prometheus) and then browse and search using the "Metric" dropdown
-	Create Panels for each metric by adding panel for the metric and choosing the right visualisation (for example graph, gauge, table,
    heatmap) and configure the panel settings eg the query, data transformation and display options and add concise title for clarity

###  Changes to dashboards and pull requests
- Any changes made to the dashboard on the UI will be overwritten in the next deployment unless added to the codebase and a pull request
  made to merge it
- In order to ensure that the new dashboard created is permanent and not deleted by subsequent deployment, add a JSON  file to the
  dashboards directory [here](https://github.com/DFE-Digital/teacher-services-cloud/tree/main/cluster/terraform_kubernetes/config/dashboards) by pasting the content of the json file exported from the dashboard and then make an entry to grafana_dashboards kubernetes_config_map resource in [grafana.tf](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/cluster/terraform_kubernetes/grafana.tf#L152C1-L153C1) file and raise a PR in order to merge the change


### Import a dashboard from json
- Log in to Grafana as admin
- Navigate to the Dashboard Import Page and click the "+" icon in the left sidebar to open the dashboard menu, select "Import" from the
  dropdown menu to access the dashboard import page.
- Import the JSON File by either clicking on "Upload JSON file" and selecting the json file from your computer or pasting the json file
  content into the text area provided
-  Click on the "Import" button to initiate the dashboard import process

### Alertmanager
The alertmanager urls corresponding to the various environments are
* Test | https://alertmanager.test.teacherservices.cloud/
* Production | https://alertmanager.teacherservices.cloud/

Authentication details are usually required but this is stored in the keyvault. Please ask in the #teacher-services-infra channel for more details.
