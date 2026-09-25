#!/usr/bin/env bash

set -euo pipefail

INPUT_CSV="servicelist.csv"
OUTPUT_JSON="shortcode_mapping.json"
EXCEPTIONS_FILE="shortcode_mapping_exceptions.csv"
DEDUPLICATION_EXCEPTIONS_FILE="shortcode_mapping_deduplication_exceptions.json"

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

tmp_output=$(mktemp)
trap 'rm -f "$tmp_output"' EXIT

if ! jq -e '
    (.short_code_to_channel | type == "array") and
    all(.short_code_to_channel[];
        (.shortCode | type == "string" and length > 0) and
        (.channelId | type == "string" and length > 0) and
        (.channelGroupId | type == "string" and length > 0))
' "$OUTPUT_JSON" >/dev/null; then
    echo "Generated mapping contains an invalid short_code_to_channel item" >&2
    exit 1
fi

jq '
    def routing: {shortCode, channelId, channelGroupId};
    def conflict_codes:
        [.short_code_to_channel[]]
        | sort_by(.shortCode)
        | group_by(.shortCode)
        | map(select((map(routing) | unique | length) > 1) | .[0].shortCode);
    def deduplicate:
        reduce .[] as $item
            ([];
             if any(.[]; routing == ($item | routing))
             then .
             else . + [$item]
             end);

    . as $mapping
    | ($mapping | conflict_codes) as $conflicts
    | {
        short_code_to_channel: ($mapping.short_code_to_channel
            | map(select(.shortCode as $code | ($conflicts | index($code)) == null))
            | deduplicate)
    }
' "$OUTPUT_JSON" > "$tmp_output"

jq '
    def routing: {shortCode, channelId, channelGroupId};

    [.short_code_to_channel[]]
    | sort_by(.shortCode)
    | group_by(.shortCode)
    | map(select((map(routing) | unique | length) > 1)
        | {
            shortCode: .[0].shortCode,
            reason: "The same shortCode has different channelId or channelGroupId values",
            items: .
        })
    ' "$OUTPUT_JSON" > "$DEDUPLICATION_EXCEPTIONS_FILE"

    mv "$tmp_output" "$OUTPUT_JSON"

trap - EXIT

echo "Created:"
echo "  $OUTPUT_JSON"
echo "  $EXCEPTIONS_FILE"
echo "  $DEDUPLICATION_EXCEPTIONS_FILE"
