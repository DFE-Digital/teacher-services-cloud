# Sample alert payloads
https://learn.microsoft.com/en-gb/azure/azure-monitor/alerts/alerts-payload-samples

We're only using the `essentials` element at the moment so the various types of alert generally don't really matter but might be used in future.
Most don't include the customProperties which we're interested in but should still be routed correctly with relevant information displayed.
```
"customProperties": {
    "target_channels": "tsc",
    "environment": "dev"
}
```
