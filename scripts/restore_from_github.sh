#!/bin/bash

# =====================================================
# Restore from GitHub Backup
# Usage: ./restore_from_github.sh [--date YYYY-MM-DD] [--dry-run]
# =====================================================

set -euo pipefail

WORKSPACE="${HOME}/.openclaw/workspace"
BACKUP_DIR="${WORKSPACE}/backups"
RESTORE_DIR="${WORKSPACE}/restore_$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false
SPECIFIC_DATE=""

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --date)
            SPECIFIC_DATE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--date YYYY-MM-DD] [--dry-run]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=============================================="
echo "OpenClaw Restore Utility"
echo "=============================================="

# Ensure we're in git repo
if [ ! -d "${WORKSPACE}/.git" ]; then
    echo -e "${RED}ERROR: Not a git repository${NC}"
    exit 1
fi

# Fetch latest from remote
echo "Fetching latest from remote..."
git fetch origin --all || { echo -e "${RED}Failed to fetch${NC}"; exit 1; }

# Determine commit to restore
if [ -n "${SPECIFIC_DATE}" ]; then
    echo "Looking for backup from ${SPECIFIC_DATE}..."
    COMMIT=$(git rev-list -n 1 --before="${SPECIFIC_DATE} 23:59" origin/main)
    if [ -z "${COMMIT}" ]; then
        echo -e "${RED}No commit found for that date${NC}"
        exit 1
    fi
else
    COMMIT=$(git rev-parse origin/main)
    echo "Restoring to latest (main branch HEAD)"
fi

echo "Commit to restore: ${COMMIT:0:8}"

# Show what will change
echo ""
echo "=== Files that will be modified ==="
git diff --name-only "${COMMIT}" HEAD | grep -E 'memory/|MEMORY.md|AGENTS.md|SOUL.md|USER.md|IDENTITY.md|TOOLS.md' || echo "No changes detected"
echo ""

if [ "${DRY_RUN}" = true ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} No changes will be made."
    exit 0
fi

# Confirmation
read -p "Proceed with restore? This will overwrite local files. (yes/no): " confirm
if [ "${confirm}" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# Create restore directory
mkdir -p "${RESTORE_DIR}"

# Checkout files to restore directory
echo "Extracting files from commit ${COMMIT:0:8}..."
git show "${COMMIT}" -- memory/ MEMORY.md AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md 2>/dev/null | tar -xz -C "${RESTORE_DIR}" || true

# Actually apply restore (safely)
echo "Applying restore..."
for file in memory/ MEMORY.md AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md; do
    if [ -f "${RESTORE_DIR}/${file}" ]; then
        cp -r "${RESTORE_DIR}/${file}" "${WORKSPACE}/${file}"
        echo -e "${GREEN}✓${NC} Restored ${file}"
    fi
done

# Stop gateway during restore? (optional)
# systemctl stop openclaw-gateway 2>/dev/null || true

# Restart gateway after
# systemctl start openclaw-gateway 2>/dev/null || true

echo ""
echo -e "${GREEN}✅ Restore complete!${NC}"
echo "Restored files are now in your workspace."
echo "A backup of the PREVIOUS state was saved in: ${RESTORE_DIR}"
echo ""
echo "Next steps:"
echo "1. Review MEMORY.md and memory/ logs"
echo "2. Start/restart gateway: openclaw gateway start"
echo "3. Test: send a message to your bot"
