#!/usr/bin/env bash

set -euo pipefail

OUTPUT_FILE="${1:-azure-devops-agent-ip-ranges.json}"

# Regions that can contain Microsoft-hosted agents for your ADO geography.
# Adjust these for your Azure DevOps organisation's geography.
REGIONS=(
    "uksouth"
    "ukwest"
)

DOWNLOAD_PAGE="https://www.microsoft.com/en-us/download/details.aspx?id=56519"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

service_tags_file="${tmp_dir}/ServiceTags_Public.json"

echo "Finding current Azure Service Tags JSON..."

download_url="$(
    curl -fsSL "$DOWNLOAD_PAGE" |
        grep -oE 'https://download\.microsoft\.com/download/[^"]+ServiceTags_Public_[0-9]+\.json' |
        head -1
)"

if [[ -z "$download_url" ]]; then
    echo "ERROR: Could not determine Service Tags download URL." >&2
    exit 1
fi

echo "Downloading:"
echo "  $download_url"

curl \
    --fail \
    --silent \
    --show-error \
    --location \
    "$download_url" \
    --output "$service_tags_file"

# Make sure what we downloaded really is JSON.
jq empty "$service_tags_file"

echo "Extracting Azure DevOps agent address ranges..."

jq \
    --argjson regions "$(printf '%s\n' "${REGIONS[@]}" | jq -R . | jq -s .)" \
    '
    {
        generatedAt: (now | todateiso8601),
        source: "Microsoft Azure Service Tags",
        regions: $regions,
        addressPrefixes: [
            .values[]
            | select(
                (.name | ascii_downcase) as $name
                | any($regions[]; $name == ("azurecloud." + ascii_downcase))
            )
            | .properties.addressPrefixes[]
        ]
        | unique
        | sort
    }
    ' \
    "$service_tags_file" > "${OUTPUT_FILE}.tmp"

# Some validation before replacing the existing holding file.
range_count="$(jq '.addressPrefixes | length' "${OUTPUT_FILE}.tmp")"

if [[ "$range_count" -eq 0 ]]; then
    echo "ERROR: No address ranges found." >&2
    rm -f "${OUTPUT_FILE}.tmp"
    exit 1
fi

mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

echo
echo "Created: $OUTPUT_FILE"
echo "Regions: ${REGIONS[*]}"
echo "Ranges:  $range_count"
