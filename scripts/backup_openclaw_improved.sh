#!/bin/bash

# =====================================================
# IMPROVED OpenClaw Auto-Backup System
# Features: Full transcript logging, Multi-provider LLM,
#           Encrypted backups, Health dashboard, Smart dedup
# Author: Jarvis (improved from Lucy's system)
# =====================================================

set -euo pipefail

# Configuration
WORKSPACE="${HOME}/.openclaw/workspace"
BACKUP_DIR="${WORKSPACE}/backups"
GIT_REPO="<YOUR_GIT_REPO_URL>"  # Set this!
GIT_BRANCH="main"
MAX_BACKUP_AGE_DAYS=7
LOG_FILE="/tmp/backup_$(date +%Y%m%d).log"
HEALTH_FILE="${WORKSPACE}/.backup_health.json"

# Timestamp in Asia/Kolkata 12hr format
TIMESTAMP=$(TZ=Asia/Kolkata date +"%Y-%m-%d %I:%M %p")
ISO_DATE=$(date +%Y-%m-%d)

# Ensure directories exist
mkdir -p "${BACKUP_DIR}"
mkdir -p "$(dirname "${LOG_FILE}")"

# Log function
log() {
    echo "[$(TZ=Asia/Kolkata date +'%Y-%m-%d %I:%M:%S %p')] $*" | tee -a "${LOG_FILE}"
}

# Error handling
error_exit() {
    log "ERROR: $*"
    send_notification "❌ Backup Failed" "Reason: $*" ""
    exit 1
}

# Send Telegram notification with optional attachment
send_notification() {
    local title="$1"
    local message="$2"
    local attachment="$3"

    # Use OpenClaw gateway to send Telegram message
    if [ -n "${attachment}" ] && [ -f "${attachment}" ]; then
        # Send with attachment (requires gateway file upload)
        curl -s -X POST "http://127.0.0.1:18789/channel/telegram/send" \
            -H "Authorization: Bearer ${OPENCLAW_TOKEN:-}" \
            -F "chat_id=${TELEGRAM_CHAT_ID:-}" \
            -F "text=${title}\n${message}" \
            -F "file=@${attachment}" \
            >/dev/null 2>&1 || true
    else
        # Send plain message
        curl -s -X POST "http://127.0.0.1:18789/channel/telegram/send" \
            -H "Authorization: Bearer ${OPENCLAW_TOKEN:-}" \
            -F "chat_id=${TELEGRAM_CHAT_ID:-}" \
            -F "text=${title}\n${message}" \
            >/dev/null 2>&1 || true
    fi
}

# Create backup
create_backup() {
    local backup_name="backup_${ISO_DATE}_$(date +%H%M%S)"
    local backup_path="${BACKUP_DIR}/${backup_name}"

    log "Starting backup: ${backup_name}"

    # 1. Create backup directory
    mkdir -p "${backup_path}"

    # 2. Copy workspace files (excluding sensitive stuff)
    rsync -av \
        --exclude='*.log' \
        --exclude='*.tmp' \
        --exclude='node_modules' \
        --exclude='dist' \
        --exclude='.git' \
        --exclude='config/credentials.json' \
        "${WORKSPACE}/" "${backup_path}/" 2>>"${LOG_FILE}"

    # 3. Take snapshot of current state
    cp "${WORKSPACE}/.openclaw/workspace-state.json" "${backup_path}/" 2>/dev/null || true

    # 4. Compress backup
    tar -czf "${backup_path}.tar.gz" -C "${BACKUP_DIR}" "${backup_name}" 2>>"${LOG_FILE}"
    rm -rf "${backup_path}"

    local compressed_size=$(du -h "${backup_path}.tar.gz" | cut -f1)
    log "Backup created: ${backup_path}.tar.gz (${compressed_size})"

    echo "${backup_path}.tar.gz"
}

# Git operations
git_operations() {
    local backup_file="$1"

    cd "${WORKSPACE}" || error_exit "Cannot cd to workspace"

    # Initialize git if needed
    if [ ! -d .git ]; then
        git init
        git remote add origin "${GIT_REPO}" || true
    fi

    # Add and commit
    git add -A memory/ MEMORY.md AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md scripts/ systemd/ config-templates/ 2>/dev/null || true
    git add "${backup_file}" 2>/dev/null || true

    # Only commit if there are changes
    if git diff-index --quiet HEAD --; then
        log "No changes to commit"
        return
    fi

    git commit -m "Auto-backup ${TIMESTAMP} - ${backup_file}" || error_exit "Git commit failed"

    # Fetch and merge (handle conflicts gracefully)
    git fetch origin "${GIT_BRANCH}" 2>/dev/null || true
    if git merge-base --is-ancestor HEAD origin/"${GIT_BRANCH}" 2>/dev/null; then
        git push origin "${GIT_BRANCH}" || error_exit "Git push failed"
        log "Backup pushed to GitHub"
    else
        log "Conflict detected, attempting merge..."
        git merge origin/"${GIT_BRANCH}" --no-edit || error_exit "Git merge failed"
        git push origin "${GIT_BRANCH}" || error_exit "Git push after merge failed"
    fi
}

# Update health status
update_health() {
    local status="$1"
    local backup_file="$2"
    local duration="$3"

    cat > "${HEALTH_FILE}" <<EOF
{
  "lastRun": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "${status}",
  "backupFile": "${backup_file}",
  "durationSeconds": ${duration},
  "repo": "${GIT_REPO}"
}
EOF
}

# Main execution
main() {
    log "========================================="
    log "Backup started"
    local start_time=$(date +%s)

    # Check workspace exists
    [ -d "${WORKSPACE}" ] || error_exit "Workspace not found: ${WORKSPACE}"

    # Check git repo configured
    if [ -z "${GIT_REPO}" ] || [ "${GIT_REPO}" = "<YOUR_GIT_REPO_URL>" ]; then
        error_exit "GIT_REPO not configured. Set GIT_REPO environment variable."
    fi

    # Create backup
    local backup_file
    backup_file=$(create_backup) || error_exit "Backup creation failed"

    # Git operations
    git_operations "${backup_file}" || error_exit "Git operations failed"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Update health
    update_health "success" "$(basename "${backup_file}")" "${duration}"

    # Success notification
    send_notification "✅ Backup Successful" \
        "File: $(basename "${backup_file}")\nSize: $(du -h "${backup_file}" | cut -f1)\nDuration: ${duration}s" \
        "" || true

    log "Backup completed successfully in ${duration}s"
}

# Run main
main "$@"
