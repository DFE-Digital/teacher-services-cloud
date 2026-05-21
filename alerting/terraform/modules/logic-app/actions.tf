resource "azurerm_logic_app_action_custom" "res-1" {
  body = jsonencode({
    actions = {
      Switch_1 = {
        cases = {
          TSC = {
            actions = {
              Post_a_message_to_myself = {
                inputs = {
                  body = {
                    body = {
                      content     = "test - TSC\n🚨 Azure Alert Triggered!\n\n🔔 Alert Rule: @{triggerBody()?['data']?['essentials']?['alertRule']}\n📛 Alert ID: @{triggerBody()?['data']?['essentials']?['alertId']}\n⚠️ Severity: @{triggerBody()?['data']?['essentials']?['severity']}\n📅 Fired At: @{triggerBody()?['data']?['essentials']?['firedDateTime']}\n📈 Metric: @{triggerBody()?['data']?['alertContext']?['condition']?['allOf'][0]?['metricName']}\n📊 Value: @{triggerBody()?['data']?['alertContext']?['condition']?['allOf'][0]?['metricValue']}\n\n🔍 View Alert: @{triggerBody()?['data']?['essentials']?['investigationLink']}\n"
                      contentType = "text"
                    }
                  }
                  host = {
                    connection = {
                      name = "@parameters('$connections')['teams-1']['connectionId']"
                    }
                  }
                  method = "post"
                  path   = "/v1.0/chats/48:notes/messages"
                }
                type = "ApiConnection"
              }
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
                      name = "@parameters('$connections')['teams-1']['connectionId']"
                    }
                  }
                  method = "post"
                  path   = "/v1.0/teams/conversation/adaptivecard/poster/Flow bot/location/@{encodeURIComponent('Channel')}"
                }
                runAfter = {
                  Post_a_message_to_myself = ["Succeeded"]
                }
                type = "ApiConnection"
              }
            }
            case = "tsc"
          }
        }
        default = {
          actions = {
            Post_message_in_a_chat_or_channel-copy = {
              inputs = {
                body = {
                  messageBody = "<p class=\"editor-paragraph\">Switch, default choice - investigate</p>"
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
                path   = "/beta/teams/conversation/message/poster/Flow bot/location/@{encodeURIComponent('Channel')}"
              }
              type = "ApiConnection"
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

resource "azurerm_logic_app_action_custom" "res-2" {
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
      }]
    }
    runAfter = {}
    type     = "InitializeVariable"
  })
  logic_app_id = azurerm_logic_app_workflow.consumption[0].id
  name         = "Initialize_Variables"
}

resource "azurerm_logic_app_action_custom" "res-3" {
  body = jsonencode({
    inputs = {
      variables = [{
        name = "AdaptiveCard"
        type = "object"
        value = {
          "$schema" = "https://adaptivecards.io/schemas/adaptive-card.json"
          body = [{
            bleed = true
            items = [{
              columns = [{
                items = [{
                  color               = "@{variables('cardStyle')}"
                  horizontalAlignment = "Left"
                  size                = "Large"
                  text                = "MyTitle"
                  type                = "TextBlock"
                }]
                type  = "Column"
                width = "stretch"
                }, {
                items = [{
                  color               = "@{variables('cardStyle')}"
                  horizontalAlignment = "Right"
                  size                = "Large"
                  spacing             = "Large"
                  text                = "MyService"
                  type                = "TextBlock"
                }]
                type  = "Column"
                width = "stretch"
              }]
              type = "ColumnSet"
              }, {
              inlines = [{
                text = "@{variables('alertRule')}"
                type = "TextRun"
              }]
              separator = true
              type      = "RichTextBlock"
            }]
            spacing = "None"
            style   = "@{variables('cardStyle')}"
            type    = "Container"
          }]
          type    = "AdaptiveCard"
          version = "1.5"
        }
      }]
    }
    runAfter = {
      SetSeverityCardStyle = ["Succeeded"]
    }
    type = "InitializeVariable"
  })
  logic_app_id = azurerm_logic_app_workflow.consumption[0].id
  name         = "SetAdaptiveCard"
}


resource "azurerm_logic_app_action_custom" "res-4" {
  body = jsonencode({
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
    runAfter = {
      Initialize_Variables = ["Succeeded"]
    }
    type = "Switch"
  })
  logic_app_id = azurerm_logic_app_workflow.consumption[0].id
  name         = "SetSeverityCardStyle"
}
