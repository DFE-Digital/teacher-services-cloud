# Alerting

We want to move from email (or email only) alerting from Azure Alerts to predominantly Teams based notifications with alerts being sent to the relevant Teams channel based on the alert payload.

This is achieved through the use of a consumption logic app which processes an alert and send an adaptive card to a Teams channel as defined in the configuration, falling back to defined channel when matches are not found or information is not provided.

Between the Logic app are Azure Alerts and Action Groups, the alert is configured by others means, typically through the services terraform and includes a target to be notified on the alert firing or returning to normal. The Action group contains the link to the logic app. Adding that link is managed by the terraform_action_groups module and only that, although creation and management of the action group is outside the scope.

## Directory Layout

```
- assets
    images and diagrams used in documentation.

- sample_payloads
    examples of payloads that can be sent to the logic app and can be used for testing.

- scripts
    bash scripts for common functions.

- terraform_action_groups
    *.tf files for configuration of the action group resources
    - config
            *.tfvars.json config files for each environment

- terraform_logic_app
    *.tf files for configuration of the alerting and associated resources
    - config
            *.tfvars.json config files for each environment

```

## Operation

### Prerequisites
- Azure Monitor Alerts and Action Groups are not created by this module, they are created separately by the services defining the alert and exist and work before use with this module. The modules adds its own logic app receivers to action groups otherwise leaving them as they are. Add Action groups you wish to connect tto the `alerting\terraform_action_groups\config\*.tfvars.json` file.

- To be routed, alerts should include customProperties `target_channels` and optionally 'environment' (not currently used). Adding these to the alerts is outside the scope of this module, for AKS services this is handled via the relevant terraform module, eg  for [redis](https://github.com/DFE-Digital/terraform-modules/blob/b889a8312e57896171f703a0a1a60c1c40c39faf/aks/redis/resources.tf#L110)

``` sample to be included in alert payload
{
"schemaId": "azureMonitorCommonAlertSchema",
    "data": {
        ...

        },
        "customProperties": {
        "target_channels": "tsc",
        "environment": "dev"
        }
    }
}
```

``` Partial Terraform example
resource "azurerm_monitor_metric_alert" "test" {
  ...

  action {
    action_group_id = "/subscriptions/5C83EB53-A94F-4778-B258-1F33EFE49655/resourceGroups/s189d01-tsc-mn-rg/providers/microsoft.insights/actionGroups/s189d01-tsc-webhook-test"
    webhook_properties = {
      target_channel = "tsc"
      environment     = "development"
    }
  }

  ...
}

```
- A mapping of short codes to Teams Channel Ids is required which is supplied to the logic app as a parameter and then used to route alerts. This may be different for development, test and production or similar depending on what stage the system is at and what testing is desired. eg for development all alerts may be routed to a particular channel or they may be routed to the same channel as production alerts.

### Alerting Build
`make <environment> alerting-plan`
`make <environment> alerting-apply`
for Test and Production `CONFIRM_<environment>=yes` is required.

### Manual API Connection Authorisation
The logic app uses a Teams Logic App connection, this needs to be connected to a user, service principles are not supported*, and requires the user authorise this connections use the first time it is setup or when it is changed (the connection, not the Workflow). To do this, once the connection as been created go to the Azure Portal and [API Connections](https://portal.azure.com/#browse/Microsoft.Web%2Fconnections). Locate the connection being used, you'll see its status on the list page or on the connection itself. If needed, select the connection:
- go to _General->Edit API Connection_
- Select Authorise and follow the prompts (MFA will be required)
- Once authorised ensure you save the changes.

### Logic App workflow updates
The logic App workflow is defined and managed through a .json file containing its definition, this can be edited directly or it can be imported into a "development" logic app, altered via the gui and then exported back to the workflow.json file dependant on the changes needed. Flow changes to the workflow are likely to be cumbersome to handle directly in the .json file whereas action or parameters renames will be a lot easier.

## Notes

*Teams API connection and service principles -  potential workarounds to introduce SPs include 3rd party solutions or implementing a custom PowerShell, Python, or other module to handle the specific operations via Azure Automation or Azure Functions.
