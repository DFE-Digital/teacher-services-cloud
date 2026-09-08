#!/usr/bin/env bash

set -euo pipefail

INPUT_CSV="servicelist.csv"
OUTPUT_JSON="shortcode_mapping.json"
EXCEPTIONS_FILE="shortcode_mapping_exceptions.csv"

urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

# Initialise output files
echo '{"short_code_to_channel": [' > "$OUTPUT_JSON"
echo 'Name,Shortname,Alertchannel,Reason' > "$EXCEPTIONS_FILE"

first=true

# Skip header row
while IFS=',' read -r name shortname alertchannel
do
    # Remove surrounding quotes if present
    name=$(echo "$name" | sed 's/^"//;s/"$//')
    shortname=$(echo "$shortname" | sed 's/^"//;s/"$//')
    alertchannel=$(echo "$alertchannel" | sed 's/^"//;s/"$//')

    # Check all required fields exist
    if [[ -z "$name" || -z "$shortname" || -z "$alertchannel" ]]; then
        printf '"%s","%s","%s","Missing required value"\n' \
            "$name" "$shortname" "$alertchannel" \
            >> "$EXCEPTIONS_FILE"
        continue
    fi

    encodedChannelId=$(
        echo "$alertchannel" |
        sed -n 's#.*\/l\/channel\/\([^/]*\)\/.*#\1#p'
    )

    channelId=$(urldecode "$encodedChannelId")

    channelGroupId=$(
        echo "$alertchannel" |
        sed -n 's#.*[?&]groupId=\([^&]*\).*#\1#p'
    )

    # Validate extraction
    if [[ -z "$channelId" || -z "$channelGroupId" ]]; then
        printf '"%s","%s","%s","Could not extract channelId or channelGroupId"\n' \
            "$name" "$shortname" "$alertchannel" \
            >> "$EXCEPTIONS_FILE"
        continue
    fi

    json=$(jq -n \
        --arg shortCode "$shortname" \
        --arg channelId "$channelId" \
        --arg channelGroupId "$channelGroupId" \
        --arg displayName "$name" \
        '{
            shortCode: $shortCode,
            channelId: $channelId,
            channelGroupId: $channelGroupId,
            displayName: $displayName
        }')

    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$OUTPUT_JSON"
    fi

    echo "$json" >> "$OUTPUT_JSON"

done < <(tail -n +2 "$INPUT_CSV")

echo ']}' >> "$OUTPUT_JSON"

echo "Created:"
echo "  $OUTPUT_JSON"
echo "  $EXCEPTIONS_FILE"
