#!/usr/bin/env bash

set -euo pipefail

OUTPUT_FILE="${1:-github-actions-agent-ip-ranges.json}"
GITHUB_META_URL="https://api.github.com/meta"

# Set true if your workflows use GitHub-hosted macOS runners.
INCLUDE_MACOS="${INCLUDE_MACOS:-false}"

tmp_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$tmp_dir"
}

trap cleanup EXIT

meta_file="${tmp_dir}/github-meta.json"
output_tmp="${tmp_dir}/output.json"

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

for command in curl jq; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERROR: Required command '$command' was not found." >&2
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Download GitHub Meta API
# ---------------------------------------------------------------------------

echo "Downloading GitHub Actions IP ranges..."

curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --retry 3 \
    --retry-delay 2 \
    --header "Accept: application/vnd.github+json" \
    --header "X-GitHub-Api-Version: 2022-11-28" \
    "$GITHUB_META_URL" \
    --output "$meta_file"

# ---------------------------------------------------------------------------
# Validate response
# ---------------------------------------------------------------------------

if ! jq empty "$meta_file" >/dev/null 2>&1; then
    echo "ERROR: GitHub Meta API returned invalid JSON." >&2
    exit 1
fi

if ! jq -e '
    (.actions | type == "array")
    and
    (.actions | length > 0)
' "$meta_file" >/dev/null
then
    echo "ERROR: GitHub Meta API did not return an actions array." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Generate holding document
# ---------------------------------------------------------------------------

if [[ "$INCLUDE_MACOS" == "true" ]]; then

    jq '
        {
            generatedAt: (now | todateiso8601),
            source: "GitHub Meta API",
            sourceUrl: "https://api.github.com/meta",
            services: [
                "actions",
                "actions_macos"
            ],
            addressPrefixes: (
                [
                    .actions[],
                    .actions_macos[]?
                ]
                | unique
                | sort
            )
        }
    ' "$meta_file" > "$output_tmp"

else

    jq '
        {
            generatedAt: (now | todateiso8601),
            source: "GitHub Meta API",
            sourceUrl: "https://api.github.com/meta",
            services: [
                "actions"
            ],
            addressPrefixes: (
                .actions
                | unique
                | sort
            )
        }
    ' "$meta_file" > "$output_tmp"

fi

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

range_count="$(
    jq '.addressPrefixes | length' "$output_tmp"
)"

if [[ "$range_count" -eq 0 ]]; then
    echo "ERROR: GitHub returned no Actions IP ranges." >&2
    exit 1
fi

# Basic CIDR sanity check.
invalid_ranges="$(
    jq -r '
        .addressPrefixes[]
        | select(test("^[^/]+/[0-9]+$") | not)
    ' "$output_tmp"
)"

if [[ -n "$invalid_ranges" ]]; then
    echo "ERROR: GitHub returned unexpected address prefixes:" >&2
    echo "$invalid_ranges" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Atomic replacement
# ---------------------------------------------------------------------------

output_dir="$(dirname "$OUTPUT_FILE")"

if [[ ! -d "$output_dir" ]]; then
    echo "ERROR: Output directory does not exist: $output_dir" >&2
    exit 1
fi

cp "$output_tmp" "${OUTPUT_FILE}.tmp"
mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

echo
echo "Created: $OUTPUT_FILE"
echo "Ranges:  $range_count"

if [[ "$INCLUDE_MACOS" == "true" ]]; then
    echo "Sources: actions + actions_macos"
else
    echo "Sources: actions"
fi