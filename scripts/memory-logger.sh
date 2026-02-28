#!/bin/bash

# =====================================================
# Full Transcript Memory Logger
# Logs every message verbatim with 12hr Asia/Kolkata time
# Format: [HH:MM AM/PM] Speaker: message
# =====================================================

set -euo pipefail

WORKSPACE="${HOME}/.openclaw/workspace"
MEMORY_DIR="${WORKSPACE}/memory"
SESSION_FILE="${WORKSPACE}/.openclaw/sessions/$(date +%Y-%m-%d).jsonl"  # Adjust based on actual session storage
TODAY=$(date +%Y-%m-%d)
MEMORY_FILE="${MEMORY_DIR}/${TODAY}.md"

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

log_message() {
    local timestamp=$(TZ=Asia/Kolkata date +"%I:%M %p")
    local speaker="$1"
    local message="$2"

    # Escape quotes in message
    local safe_message=$(echo "${message}" | sed 's/"/\\"/g')

    echo "[${timestamp}] ${speaker}: ${message}" | tee -a "${MEMORY_FILE}"
}

# Initialize daily memory file if not exists
init_memory_file() {
    if [ ! -f "${MEMORY_FILE}" ]; then
        mkdir -p "${MEMORY_DIR}"
        cat > "${MEMORY_FILE}" <<EOF
# Memory Log - ${TODAY}

## Session Start

**Time:** $(TZ=Asia/Kolkata date +"%Y-%m-%d %I:%M %p")
**Agent:** Jarvis 🤖
**User:** Amit

### Conversation Transcript

EOF
        echo -e "${GREEN}✓${NC} Initialized memory file: ${MEMORY_FILE}"
    fi
}

# Append message to memory
# Usage: log_to_memory "Speaker" "message text"
log_to_memory() {
    init_memory_file
    log_message "$1" "$2"
}

# Update MEMORY.md with curated highlights (to be called separately)
curate_memory() {
    local CURATED_MEMORY="${WORKSPACE}/MEMORY.md"
    local today_summary=""

    # Extract key points from today's log (simple heuristic)
    if [ -f "${MEMORY_FILE}" ]; then
        today_summary=$(grep -E '^\[.*\] ' "${MEMORY_FILE}" | head -20 | sed 's/^\[.*\] //' | awk -F': ' '{print "- "$0}' | head -10)
    fi

    cat > "${CURATED_MEMORY}" <<EOF
# MEMORY.md — Curated Long-Term Memories

**Agent:** Jarvis  
**User:** Amit  
**Last updated:** ${TODAY} (Asia/Kolkata)

---

## 👨‍👩‍👦 Family

- (add family details as learned)

## 🏢 Business

- (add business details as learned)

## 🛠️ Technical Setup

- Gateway: Local (127.0.0.1:18789)
- Backup: Improved system with full transcripts
- LLM: OpenRouter + fallback providers
- Memory: Daily logs + curated highlights

## 📝 Preferences

- Respectful address: "aap" (formal), not "tum"
- 12-hour Asia/Kolkata time format
- Full verbatim transcript logging
- 5-minute auto-backup with Telegram notifications

---

*This file is curated from daily logs. Update periodically.*

${today_summary}
EOF
    echo -e "${GREEN}✓${NC} Curated memory updated"
}

# If script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <speaker> <message>"
        exit 1
    fi
    log_to_memory "$1" "$2"
fi
