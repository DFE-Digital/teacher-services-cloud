#!/usr/bin/env bash

INPUT_CSV="actiongroups.csv"
OUTPUT_JSON="actiongroups.json"

json='{}'

while IFS=, read -r name resourceGroup
do
    name=$(printf '%s' "$name" | tr -d '"')
    resourceGroup=$(printf '%s' "$resourceGroup" | tr -d '"')

    json=$(printf '%s\n' "$json" | jq \
        --arg name "$name" \
        --arg rg "$resourceGroup" \
        '. + {
            ($name): {
                name: $name,
                resource_group_name: $rg
            }
        }')
done < <(tail -n +2 "$INPUT_CSV")

jq -n \
    --argjson ag "$json" \
    '{action_groups_to_hookup: $ag}' \
    > "$OUTPUT_JSON"

echo "JSON written to $OUTPUT_JSON"
