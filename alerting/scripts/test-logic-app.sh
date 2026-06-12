#read -p "enter callback URL to test: " callbackurl


curl -sS -X POST -H "Content-Type: application/json" --data-binary @- "$callbackurl" <<'JSON'
{
"schemaId": "azureMonitorCommonAlertSchema",
"data": {
    "essentials": {
    "alertId": "/subscriptions/3c033a0c-7a1c-4653-93cb-0f2a9f57a391/providers/Microsoft.AlertsManagement/alerts/fb0dee86-ff6a-681f-36d3-529da39ff000",

    "alertRule": "test-availabilityTest-test-applicationInsights",
    "severity": "Sev1",
    "signalType": "Metric",
    "monitorCondition": "Fired",
    "monitoringService": "Platform",
    "alertTargetIDs": [
        "/subscriptions/3c033a0c-7a1c-4653-93cb-0f2a9f57a391/resourcegroups/s189p01-tsc-aks-nodes-production-rg/providers/microsoft.compute/virtualmachinescalesets/aks-apps1-29533562-vmss/virtualmachines/212"
    ],
    "configurationItems": [
        "test-applicationInsights"
    ],
    "originAlertId": "aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e_test-RG_microsoft.insights_metricalerts_test-availabilityTest-test-applicationInsights_1234567890",
    "firedDateTime": "2025-04-15T17:42:34.824Z",
    "description": "Alertruledescription",
    "essentialsVersion": "1.0",
    "alertContextVersion": "1.0"
    },
    "alertContext": {
    "properties": null,
    "conditionType": "WebtestLocationAvailabilityCriteria",
    "condition": {
        "windowSize": "PT5M",
        "allOf": [
        {
            "metricName": "FailedLocation",
            "metricNamespace": null,
            "operator": "GreaterThan",
            "threshold": "2",
            "timeAggregation": "Sum",
            "dimensions": [],
            "metricValue": 5.0,
            "webTestName": "test-availabilityTest-test-applicationInsights"
        }
        ],
        "windowStartTime": "2025-04-15T17:42:34.824Z",
        "windowEndTime": "2025-04-15T17:42:34.824Z"
    }
    },
    "customProperties": {
    "target_channels": "tsc",
    "environment": "dev"
    }
}
}
JSON
