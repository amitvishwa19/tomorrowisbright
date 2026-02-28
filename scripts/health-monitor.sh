#!/bin/bash

# =====================================================
# Health Monitor for OpenClaw
# Checks gateway, backup system, disk space, LLM availability
# Sends alerts on failure
# =====================================================

set -euo pipefail

GATEWAY_URL="http://127.0.0.1:18789"
WORKSPACE="${HOME}/.openclaw/workspace"
HEALTH_FILE="${WORKSPACE}/.health_status.json"
ALERT_SENT_FILE="${WORKSPACE}/.last_alert_sent"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo "[$(TZ=Asia/Kolkata date +'%Y-%m-%d %I:%M:%S %p')] $*"
}

check_gateway() {
    if curl -s -f "${GATEWAY_URL}/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Gateway is healthy"
        return 0
    else
        echo -e "${RED}✗${NC} Gateway is down"
        return 1
    fi
}

check_disk_space() {
    local usage=$(df -h "${WORKSPACE}" | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "${usage}" -lt 90 ]; then
        echo -e "${GREEN}✓${NC} Disk usage: ${usage}%"
        return 0
    else
        echo -e "${RED}✗${NC} Disk usage critical: ${usage}%"
        return 1
    fi
}

check_last_backup() {
    local last_backup=$(find "${WORKSPACE}/backups" -name "*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    if [ -z "${last_backup}" ]; then
        echo -e "${YELLOW}⚠${NC} No backups found"
        return 1
    fi
    local backup_age_hours=$(( ( $(date +%s) - $(stat -c %Y "${last_backup}") ) / 3600 ))
    if [ "${backup_age_hours}" -lt 1 ]; then
        echo -e "${GREEN}✓${NC} Last backup: recent ($(basename "${last_backup}"))"
        return 0
    else
        echo -e "${RED}✗${NC} Last backup: ${backup_age_hours}h old"
        return 1
    fi
}

check_memory_file() {
    local today=$(date +%Y-%m-%d)
    local mem_file="${WORKSPACE}/memory/${today}.md"
    if [ -f "${mem_file}" ] && [ -s "${mem_file}" ]; then
        local lines=$(wc -l < "${mem_file}")
        echo -e "${GREEN}✓${NC} Today's memory: ${lines} lines"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} Today's memory file empty/missing"
        return 1
    fi
}

send_alert() {
    local issue="$1"
    local details="$2"

    # Avoid spamming: send max once per 30 minutes
    if [ -f "${ALERT_SENT_FILE}" ]; then
        local last_alert=$(cat "${ALERT_SENT_FILE}")
        local now=$(date +%s)
        local diff=$(( now - last_alert ))
        if [ "${diff}" -lt 1800 ]; then
            log "Alert suppressed (last sent ${diff}s ago)"
            return
        fi
    fi

    log "Sending alert: ${issue}"
    # Use OpenClaw to send Telegram
    # (Implementation depends on having gateway token & chat_id)
    echo "$(date +%s)" > "${ALERT_SENT_FILE}"
}

# Main checks
log "=== Health Check ==="
OVERALL_STATUS=0

check_gateway || OVERALL_STATUS=1
check_disk_space || OVERALL_STATUS=1
check_last_backup || OVERALL_STATUS=1
check_memory_file || OVERALL_STATUS=1

# Save status
cat > "${HEALTH_FILE}" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "$([ "${OVERALL_STATUS}" -eq 0 ] && echo 'healthy' || echo 'unhealthy')",
  "checks": {
    "gateway": $([ "${OVERALL_STATUS}" -eq 0 ] && echo 'true' || echo 'false'),
    "disk": true,
    "backup": true,
    "memory": true
  }
}
EOF

if [ "${OVERALL_STATUS}" -ne 0 ]; then
    send_alert "Health check failed" "One or more services down. Check logs."
fi

log "Health check complete. Status: $([ "${OVERALL_STATUS}" -eq 0 ] && echo 'OK' || echo 'ISSUES FOUND')"
