resource "azurerm_logic_app_action_custom" "res-1" {
  body = jsonencode({
    actions = {
      Set_variable_1 = {
        inputs = {
          name  = "multipleTargets"
          value = false
        }
        type = "SetVariable"
      }
    }
    else = {
      actions = {
        Set_variable_1-copy = {
          inputs = {
            name  = "multipleTargets"
            value = true
          }
          type = "SetVariable"
        }
      }
    }
    expression = {
      and = [{
        equals = ["@length(variables('alertTargetIDs'))", 1]
      }]
    }
    runAfter = {
      Initialize_Variables = ["Succeeded"]
    }
    type = "If"
  })
  logic_app_id = azurerm_logic_app_workflow.consumption[0].id
  name         = "Condition"
}
resource "azurerm_logic_app_action_custom" "res-2" {
  body = jsonencode({
    actions = {
      PostToChannel = {
        cases = {
          TSC = {
            actions = {
              Post_card_in_a_chat_or_channel = {
                inputs = {
                  body = {
                    messageBody = "@string(variables('AdaptiveCard'))"
                    recipient = {
                      channelId = "19:7a37601cb9f34d448f185c240b73ebce@thread.tacv2"
                      groupId   = "88f2c5be-5902-4ffa-a7f6-e327b30b0ab1"
                    }
                  }
                  host = {
                    connection = {
                      name = "@parameters('$connections')['teams']['connectionId']"
                    }
                  }
                  method = "post"
                  path   = "/v1.0/teams/conversation/adaptivecard/poster/Flow bot/location/@{encodeURIComponent('Channel')}"
                }
                type = "ApiConnection"
              }
            }
            case = "tsc"
          }
        }
        default = {
          actions = {
            Post_card_in_a_chat_or_channel-copy = {
              inputs = {
                body = {
                  messageBody = "@string(variables('AdaptiveCard'))"
                  recipient = {
                    channelId = "19:7a37601cb9f34d448f185c240b73ebce@thread.tacv2"
                    groupId   = "88f2c5be-5902-4ffa-a7f6-e327b30b0ab1"
                  }
                }
                host = {
                  connection = {
                    name = "@parameters('$connections')['teams']['connectionId']"
                  }
                }
                method = "post"
                path   = "/v1.0/teams/conversation/adaptivecard/poster/Flow bot/location/@{encodeURIComponent('Channel')}"
              }
              runAfter = {
                Set_variable = ["Succeeded"]
              }
              type = "ApiConnection"
            }
            Set_variable = {
              inputs = {
                name  = "cardStyle"
                value = "warning"
              }
              type = "SetVariable"
            }
          }
        }
        expression = "@items('For_each')"
        type       = "Switch"
      }
    }
    foreach = "@variables('target_channels')"
    runAfter = {
      SetAdaptiveCard = ["Succeeded"]
    }
    type = "Foreach"
  })
  logic_app_id = azurerm_logic_app_workflow.consumption[0].id
  name         = "For_each"
}
resource "azurerm_logic_app_action_custom" "res-3" {
  body = jsonencode({
    actions = {}
    foreach = "@variables('alertTargetIDs')"
    runAfter = {
      Condition = ["Succeeded"]
    }
    type = "Foreach"
  })
  logic_app_id = azurerm_logic_app_workflow.consumption[0].id
  name         = "For_each_1"
}
resource "azurerm_logic_app_action_custom" "res-4" {
  body = jsonencode({
    inputs = {
      variables = [{
        name  = "target_channels"
        type  = "array"
        value = "@split(string(triggerBody()?['data']?['customProperties']?['target_channels']),',')"
        }, {
        name  = "environment"
        type  = "string"
        value = "@{triggerBody()?['data']?['customProperties']?['environment']}"
        }, {
        name  = "alertRule"
        type  = "string"
        value = "@{triggerBody()?['data']?['essentials']?['alertRule']}"
        }, {
        name  = "severity"
        type  = "string"
        value = "@{triggerBody()?['data']?['essentials']?['severity']}"
        }, {
        name  = "monitorCondition"
        type  = "string"
        value = "@{triggerBody()?['data']?['essentials']?['monitorCondition']}"
        }, {
        name  = "alertTargetIDs"
        type  = "array"
        value = "@triggerBody()?['data']?['essentials']?['alertTargetIDs']"
        }, {
        name  = "cardStyle"
        type  = "string"
        value = "Default"
        }, {
        name  = "monitoringService"
        type  = "string"
        value = "@{triggerBody()?['data']?['essentials']?['monitoringService']}"
        }, {
        name  = "alertId"
        type  = "string"
        value = "@{triggerBody()?['data']?['essentials']?['alertId']}"
        }, {
        name  = "Description"
        type  = "string"
        value = "@{triggerBody()?['data']?['essentials']?['description']}"
        }, {
        name  = "resourceGroup"
        type  = "string"
        value = "@{split(first(triggerBody()?['data']?['essentials']?['alertTargetIDs']),'/')[4]}"
        }, {
        name  = "multipleTargets"
        type  = "boolean"
        value = false
        }, {
        name  = "targetId"
        type  = "string"
        value = "@{first(triggerBody()?['data']?['essentials']?['alertTargetIDs'])}"
        }, {
        name  = "resourceName"
        type  = "string"
        value = "@{split(first(triggerBody()?['data']?['essentials']?['alertTargetIDs']),'/')[8]}"
        }, {
        name  = "alertEventUrl"
        type  = "string"
        value = "@{concat(    'https://portal.azure.com/#blade/Microsoft_Azure_Monitoring/AlertDetailsTemplateBlade/alertId/',  encodeUriComponent(triggerBody()['data']['essentials']['alertId']))}"
        }, {
        name  = "resourceUrl"
        type  = "string"
        value = "@{concat('https://portal.azure.com/',parameters('tenantId'),'/resource/',first(triggerBody()?['data']?['essentials']?['alertTargetIDs']))}"
        }, {
        name  = "resourceType"
        type  = "string"
        value = "@{concat(split(first(triggerBody()?['data']?['essentials']?['alertTargetIDs']),'/')[6],'/',split(first(triggerBody()?['data']?['essentials']?['alertTargetIDs']),'/')[7])}"
      }]
    }
    runAfter = {}
    type     = "InitializeVariable"
  })
  logic_app_id = azurerm_logic_app_workflow.consumption[0].id
  name         = "Initialize_Variables"
}
resource "azurerm_logic_app_action_custom" "res-5" {
  body = jsonencode({
    inputs = {
      variables = [{
        name = "AdaptiveCard"
        type = "object"
        value = {
          "$schema" = "https://adaptivecards.io/schemas/adaptive-card.json"
          actions = [{
            title = "View Alert"
            type  = "Action.OpenUrl"
            url   = "@{variables('alertEventUrl')}"
            }, {
            title = "View Resource"
            type  = "Action.OpenUrl"
            url   = "@{variables('resourceUrl')}"
          }]
          body = [{
            bleed = true
            items = [{
              columns = [{
                items = [{
                  size   = "Large"
                  text   = "@{variables('alertRule')}"
                  type   = "TextBlock"
                  weight = "Bolder"
                  wrap   = true
                }]
                type  = "Column"
                width = "stretch"
                }, {
                items = [{
                  color               = "@{variables('cardStyle')}"
                  horizontalAlignment = "Right"
                  size                = "Large"
                  text                = "@{variables('monitorCondition')}"
                  type                = "TextBlock"
                  weight              = "Bolder"
                }]
                type  = "Column"
                width = "auto"
              }]
              type = "ColumnSet"
              }, {
              inlines = [{
                text   = "Severity: "
                type   = "TextRun"
                weight = "Bolder"
                }, {
                text = "@{variables('severity')}"
                type = "TextRun"
              }]
              separator = true
              type      = "RichTextBlock"
            }]
            spacing = "None"
            style   = "@{variables('cardStyle')}"
            type    = "Container"
            }, {
            items = [{
              facts = [{
                title = "Alert Name"
                value = "@{variables('alertRule')}"
                }, {
                title = "Severity"
                value = "@{variables('severity')}"
                }, {
                title = "Monitor Condition"
                value = "@{variables('monitorCondition')}"
                }, {
                title = "Afected Resource"
                value = "@{variables('targetId')}"
                }, {
                title = "Resource Group"
                value = "@{variables('resourceGroup')}"
                }, {
                title = "Resource Type"
                value = "@{variables('resourceType')}"
                }, {
                title = "Monitoring Service"
                value = "@{variables('monitoringService')}"
                }, {
                title = "Description"
                value = "@{variables('Description')}"
              }]
              type = "FactSet"
            }]
            type = "Container"
          }]
          type    = "AdaptiveCard"
          version = "1.5"
        }
      }]
    }
    runAfter = {
      SetCardStyle = ["Succeeded"]
    }
    type = "InitializeVariable"
  })
  logic_app_id = azurerm_logic_app_workflow.consumption[0].id
  name         = "SetAdaptiveCard"
}
resource "azurerm_logic_app_action_custom" "res-6" {
  body = jsonencode({
    actions = {
      SetCardStyleGood = {
        inputs = {
          name  = "cardStyle"
          value = "Good"
        }
        type = "SetVariable"
      }
    }
    else = {
      actions = {
        SetSeverityCardStyle = {
          cases = {
            Sev1 = {
              actions = {
                SetStyleAttention = {
                  inputs = {
                    name  = "cardStyle"
                    value = "Attention"
                  }
                  type = "SetVariable"
                }
              }
              case = "Sev1"
            }
            Sev2 = {
              actions = {
                SetStyleAttention2 = {
                  inputs = {
                    name  = "cardStyle"
                    value = "Attention"
                  }
                  type = "SetVariable"
                }
              }
              case = "Sev2"
            }
            Sev3 = {
              actions = {
                SetStyleWarning = {
                  inputs = {
                    name  = "cardStyle"
                    value = "Warning"
                  }
                  type = "SetVariable"
                }
              }
              case = "Sev3"
            }
            Sev4 = {
              actions = {
                SetStyleWarning2 = {
                  inputs = {
                    name  = "cardStyle"
                    value = "Warning"
                  }
                  type = "SetVariable"
                }
              }
              case = "Sev4"
            }
          }
          default = {
            actions = {
              SetStyleWarning3 = {
                inputs = {
                  name  = "cardStyle"
                  value = "Warning"
                }
                type = "SetVariable"
              }
            }
          }
          expression = "@variables('severity')"
          type       = "Switch"
        }
      }
    }
    expression = {
      and = [{
        equals = ["@variables('monitorCondition')", "Resolved"]
      }]
    }
    runAfter = {
      For_each_1 = ["Succeeded"]
    }
    type = "If"
  })
  logic_app_id = azurerm_logic_app_workflow.consumption[0].id
  name         = "SetCardStyle"
}
