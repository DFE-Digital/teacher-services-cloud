#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

callbackurl="${CALLBACK_URL:-}"
json_file="$SCRIPT_DIR/../sample_payloads/alert_payload.json"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -u, --url URL      Logic App callback URL
  -f, --file FILE    JSON payload file
  -h, --help         Show this help

Examples:
  $(basename "$0")
  $(basename "$0") --url "https://..."
  $(basename "$0") --file custom_payload.json
  $(basename "$0") --url "https://..." --file payload.json

Environment variables:
  CALLBACK_URL       Logic App callback URL
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--url)
            callbackurl="$2"
            shift 2
            ;;
        -f|--file)
            json_file="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$callbackurl" ]]; then
    # NOTE: Do NOT store this in the script, it contains the SAS token
    read -rp "Enter Logic App callback URL: " callbackurl
fi

# If only a filename was supplied, look in sample_payloads
if [[ ! "$json_file" = /* ]]; then
    json_file="$SCRIPT_DIR/../sample_payloads/$json_file"
fi

if [[ ! -f "$json_file" ]]; then
    echo "JSON file not found: $json_file" >&2
    exit 1
fi

curl -sS \
    -X POST \
    -H "Content-Type: application/json" \
    --data-binary @"$json_file" \
    "$callbackurl"
