resource "azurerm_logic_app_trigger_http_request" "this" {
  name         = "When_an_HTTP_request_is_received"
  logic_app_id = azurerm_logic_app_workflow.consumption[0].id

  schema = <<SCHEMA
{
  "type": "object",
  "properties": {
    "schemaId": {
      "type": "string"
    },
    "data": {
      "type": "object",
      "properties": {
        "essentials": {
          "type": "object",
          "properties": {
            "alertId": {
              "type": "string"
            },
            "alertRule": {
              "type": "string"
            },
            "severity": {
              "type": "string"
            },
            "signalType": {
              "type": "string"
            },
            "monitorCondition": {
              "type": "string"
            },
            "monitoringService": {
              "type": "string"
            },
            "alertTargetIDs": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "configurationItems": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "originAlertId": {
              "type": "string"
            },
            "firedDateTime": {
              "type": "string"
            },
            "description": {
              "type": "string"
            },
            "essentialsVersion": {
              "type": "string"
            },
            "alertContextVersion": {
              "type": "string"
            }
          }
        },
        "alertContext": {
          "type": "object",
          "properties": {
            "properties": {},
            "conditionType": {
              "type": "string"
            },
            "condition": {
              "type": "object",
              "properties": {
                "windowSize": {
                  "type": "string"
                },
                "allOf": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "metricName": {
                        "type": "string"
                      },
                      "metricNamespace": {},
                      "operator": {
                        "type": "string"
                      },
                      "threshold": {
                        "type": "string"
                      },
                      "timeAggregation": {
                        "type": "string"
                      },
                      "dimensions": {
                        "type": "array"
                      },
                      "metricValue": {
                        "type": "integer"
                      },
                      "webTestName": {
                        "type": "string"
                      }
                    },
                    "required": [
                      "metricName",
                      "metricNamespace",
                      "operator",
                      "threshold",
                      "timeAggregation",
                      "dimensions",
                      "metricValue",
                      "webTestName"
                    ]
                  }
                },
                "windowStartTime": {
                  "type": "string"
                },
                "windowEndTime": {
                  "type": "string"
                }
              }
            }
          }
        },
        "customProperties": {
          "type": "object",
          "properties": {
            "target_channels": {
              "type": "string"
            },
            "environment": {
              "type": "string"
            }
          }
        }
      }
    }
  }
}
SCHEMA

}
