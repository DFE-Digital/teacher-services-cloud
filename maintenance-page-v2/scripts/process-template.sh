#!/usr/bin/env bash

set -eu

# Load environment configuration
CONFIG=${1:-production}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source environment config
if [[ -f "${PROJECT_ROOT}/global_config/${CONFIG}.sh" ]]; then
    source "${PROJECT_ROOT}/global_config/${CONFIG}.sh"
fi

# Load service configuration from Makefile
if [[ -f "${PROJECT_ROOT}/Makefile" ]]; then
    SERVICE_NAME=$(grep "^SERVICE_NAME=" "${PROJECT_ROOT}/Makefile" | cut -d'=' -f2 | tr -d ' ')
    SERVICE_SHORT=$(grep "^SERVICE_SHORT=" "${PROJECT_ROOT}/Makefile" | cut -d'=' -f2 | tr -d ' ')
fi

# Load from terraform config if available
TFVARS_FILE="${PROJECT_ROOT}/terraform/application/config/${CONFIG}.tfvars.json"
if [[ -f "${TFVARS_FILE}" ]]; then
    # Extract service_pretty_name if defined
    SERVICE_PRETTY=$(jq -r '.service_pretty_name // empty' "${TFVARS_FILE}")
    if [[ -z "${SERVICE_PRETTY}" ]]; then
        # Fallback to service_name with title case
        SERVICE_PRETTY=$(jq -r '.service_name // empty' "${TFVARS_FILE}" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
    fi
fi

# Fallback to SERVICE_NAME if SERVICE_PRETTY not found
SERVICE_PRETTY=${SERVICE_PRETTY:-${SERVICE_NAME:-"Service"}}

# Load maintenance configuration
MAINT_CONFIG="${SCRIPT_DIR}/../config/maint-config.txt"
if [[ ! -f "${MAINT_CONFIG}" ]]; then
    echo "Error: maint-config.txt not found. Copy maint-config.txt.example and customize it."
    exit 1
fi

# Source the maintenance config
source "${MAINT_CONFIG}"

# Process contact information
CONTACT_INFO=""
if [[ -n "${CONTACT_EMAIL:-}" ]]; then
    CONTACT_INFO="${CONTACT_INFO}<li>Email: <a href='mailto:${CONTACT_EMAIL}' class='govuk-link'>${CONTACT_EMAIL}</a></li>"
fi
if [[ -n "${CONTACT_PHONE:-}" ]]; then
    CONTACT_INFO="${CONTACT_INFO}<li>Phone: ${CONTACT_PHONE}</li>"
fi
if [[ -n "${CONTACT_SLACK:-}" ]]; then
    CONTACT_INFO="${CONTACT_INFO}<li>Slack: ${CONTACT_SLACK}</li>"
fi
if [[ -n "${CONTACT_TEAMS:-}" ]]; then
    CONTACT_INFO="${CONTACT_INFO}<li>Teams: ${CONTACT_TEAMS}</li>"
fi

# Default contact info if none provided
if [[ -z "${CONTACT_INFO}" ]]; then
    CONTACT_INFO="<li>Email: <a href='mailto:support@education.gov.uk' class='govuk-link'>support@education.gov.uk</a></li>"
fi

# Create output directory
OUTPUT_DIR="${SCRIPT_DIR}/../output"
mkdir -p "${OUTPUT_DIR}"

# Process template
TEMPLATE="${SCRIPT_DIR}/../templates/index.html.template"
OUTPUT="${OUTPUT_DIR}/index.html"

echo "Processing maintenance page template..."
echo "  Service: ${SERVICE_PRETTY}"
echo "  Config: ${CONFIG}"
echo "  Message: ${MAINTENANCE_MESSAGE}"

# Use sed to replace placeholders
cp "${TEMPLATE}" "${OUTPUT}"

# Replace placeholders
sed -i.bak "s|#SERVICE_PRETTY#|${SERVICE_PRETTY}|g" "${OUTPUT}"
sed -i.bak "s|#MAINTENANCE_MESSAGE#|${MAINTENANCE_MESSAGE}|g" "${OUTPUT}"
sed -i.bak "s|#ESTIMATED_RETURN#|${ESTIMATED_RETURN:-}|g" "${OUTPUT}"
sed -i.bak "s|#STATUS_PAGE#|${STATUS_PAGE:-}|g" "${OUTPUT}"
sed -i.bak "s|#CONTACT_INFO#|${CONTACT_INFO}|g" "${OUTPUT}"

# Clean up backup file
rm -f "${OUTPUT}.bak"

echo "✅ Maintenance page generated: ${OUTPUT}"