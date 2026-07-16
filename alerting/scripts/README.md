# Scripts

## test-logicapp.sh
This can be used to send an alert payload to a Logic App. To use copy the Logic App Workflow URL from the Logic App in the Azure Portal and export or set the CALLBACK_URL.
`export CALLBACK_URL="<URL>"`
DO NOT save the URL, it contains a SAS token.
You can either supply a specific payload file or use one of the samples
eg `./test-logicapp.sh -f alert_payload_no_custom_details.json`

## ag-convert-csv-to-json.sh
This script can be used to convert a csv list of Action Groups into the required json format for the `action_groups_to_hookup` config element.
To use, produce a list of Action Groups, easiest option is export from Az CLI or the Azure Resource Graph Explorer in the portal:
```
resources
| where type == 'microsoft.insights/actiongroups'
| where properties["enabled"] in~ ('true')
| project name,resourceGroup
```
The source file must contain columns `name,resourceGroup`, within the script these values are set for input and output files:
```
INPUT_CSV="actiongroups.csv"
OUTPUT_JSON="actiongroups.json"
```

## servicelist-to-json.sh
This script can be used to (re-)produce the short code to Teams channel mapping based on an extract of the [Schools Digital Services service list](https://educationgovuk.sharepoint.com/sites/teacher-services-infrastructure/Lists/Teacher%20services%20list/AllItems.aspx?viewid=93faa944%2D7992%2D4bc2%2D836f%2Dbb7552c919c3).

To re-generate, export the list to a csv, trim down to only columns `Name,Shortname,Alertchannel` and remove spaces from the column names.
Save in the scripts folder naming the file `actiongroups.csv`

The script uses these predfined values for input and output files.
```
INPUT_CSV="servicelist.csv"
OUTPUT_JSON="shortcode_mapping.json"
EXCEPTIONS_FILE="shortcode_mapping_exceptions.csv"
```

run `./servicelist-to-json.sh`

This will produce a `actiongroups.json` file which is just the `short_code_to_channel` element, manually copy and paste this into the desired environment config file.
