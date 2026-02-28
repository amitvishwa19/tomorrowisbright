#!/bin/bash

# =====================================================
# Safe Config Update Tool (Improved)
# Edits openclaw.json safely with jq validation
# Features: backup, diff, confirm, auto-restart gateway
# =====================================================

set -euo pipefail

CONFIG_FILE="${HOME}/.openclaw/openclaw.json"
BACKUP_DIR="${HOME}/.openclaw/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] <jq_expression> <new_value>

Edit openclaw.json safely with jq expression.

OPTIONS:
  -y, --yes           Skip confirmation prompt
  -r, --restart       Restart gateway after successful update
  -b, --backup        Create timestamped backup (default: yes)
  -h, --help          Show this help message

EXAMPLES:
  $0 '.channels.telegram.botToken' '"NEW_TOKEN"'
  $0 -r '.gateway.port' '18790'
  $0 -y '.plugins.entries.whatsapp.enabled' 'true'

EOF
    exit 1
}

# Parse arguments
AUTO_YES=false
RESTART_GATEWAY=false
CREATE_BACKUP=true

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes) AUTO_YES=true; shift ;;
        -r|--restart) RESTART_GATEWAY=true; shift ;;
        -b|--backup) CREATE_BACKUP=true; shift ;;
        -h|--help) usage ;;
        *) break ;;
    esac
done

# Require exactly 2 positional arguments
if [ $# -ne 2 ]; then
    usage
fi

JQ_EXPR="$1"
NEW_VALUE="$2"

# Check jq exists
if ! command -v jq &>/dev/null; then
    echo -e "${RED}ERROR: jq is not installed${NC}"
    exit 1
fi

# Check config exists
if [ ! -f "${CONFIG_FILE}" ]; then
    echo -e "${RED}ERROR: Config not found: ${CONFIG_FILE}${NC}"
    exit 1
fi

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Step 1: Create backup
if [ "${CREATE_BACKUP}" = true ]; then
    BACKUP_FILE="${BACKUP_DIR}/openclaw_${TIMESTAMP}.json"
    cp "${CONFIG_FILE}" "${BACKUP_FILE}"
    echo -e "${GREEN}✓${NC} Backup created: $(basename "${BACKUP_FILE}")"
fi

# Step 2: Validate new value JSON
echo -n "Validating new value... "
if ! echo "${NEW_VALUE}" | jq . >/dev/null 2>&1; then
    echo -e "${RED}FAIL${NC}"
    echo "ERROR: Invalid JSON value: ${NEW_VALUE}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# Step 3: Show diff preview
echo "=== Preview of changes ==="
TMP_FILE=$(mktemp)
jq "${JQ_EXPR}" "${CONFIG_FILE}" > "${TMP_FILE}" 2>/dev/null || {
    echo -e "${RED}ERROR: Invalid jq expression: ${JQ_EXPR}${NC}"
    exit 1
}
echo "Current: $(cat "${TMP_FILE}" 2>/dev/null || echo 'null')"
echo "New:     ${NEW_VALUE}"
rm -f "${TMP_FILE}"

# Step 4: Confirmation
if [ "${AUTO_YES}" = false ]; then
    read -p "Apply this change? (y/N): " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Step 5: Apply change
echo "Applying change..."
if jq "${JQ_EXPR} = ${NEW_VALUE}" "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp"; then
    mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
    echo -e "${GREEN}✓${NC} Config updated successfully"
else
    echo -e "${RED}ERROR: Failed to apply change${NC}"
    rm -f "${CONFIG_FILE}.tmp"
    exit 1
fi

# Step 6: Show diff
echo "=== Diff ==="
if command -v diff &>/dev/null; then
    diff -u "${BACKUP_FILE}" "${CONFIG_FILE}" || true
fi

# Step 7: Restart gateway if requested
if [ "${RESTART_GATEWAY}" = true ]; then
    echo "Restarting gateway..."
    if command -v openclaw &>/dev/null; then
        openclaw gateway restart && echo -e "${GREEN}✓${NC} Gateway restarted"
    else
        echo -e "${YELLOW}WARN: openclaw command not found, skip restart${NC}"
    fi
fi

echo -e "${GREEN}All done!${NC}"
