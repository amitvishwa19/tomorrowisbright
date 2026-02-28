# 🚀 OpenClaw Advanced Setup — Jarvis Edition

**Improved backup & monitoring system for OpenClaw agents.**

> This setup builds on Lucy's solid foundation with reliability, monitoring, and multi-provider intelligence upgrades.

---

## 📋 Features

### ✅ Core Stability (from Lucy)
- Auto-backup every 5 minutes → GitHub
- Full verbatim conversation transcript
- 12-hour Asia/Kolkata timestamps
- Telegram notifications
- Gateway self-healing (systemd + watchdog)

### 🔥 New Improvements
- **Multi-provider LLM**: Auto-failover (OpenRouter → Google AI Studio → local fallback)
- **Encrypted backups**: Sensitive files encrypted with age/gpg
- **Health dashboard**: `/health` endpoint with metrics
- **Smart Git dedup**: Avoid empty commits, squash redundant changes
- **Config versioning**: Automatic rollback snapshots
- **Enhanced notifications**: Success/Failure/retry with context
- **Multi-agent ready**: Supports multiple agent workspaces
- **Restore testing**: Automated validation of backups

---

## 📁 Structure

```
workspace/
├── scripts/
│   ├── backup_openclaw_improved.sh   # Main backup (5-min cron)
│   ├── memory-logger.sh              # Full transcript logger
│   ├── safe-config-update-improved.sh # Safe config edits
│   ├── restore_from_github.sh        # Restore utility
│   └── health-monitor.sh             # Health checks
├── systemd/
│   └── openclaw-gateway.service     # Self-healing service
├── config-templates/
│   ├── openclaw.json.template       # Base config
│   └── llm-providers.json           # Multi-provider LLM config
├── memory/
│   ├── 2026-02-27.md                # Daily logs (full transcript)
│   └── MEMORY.md                    # Curated long-term
├── AGENTS.md
├── SOUL.md
├── USER.md
├── IDENTITY.md
└── README.md                        # This file

```

---

## 🛠️ Setup Guide

### 1. Prerequisites
- Node.js 20+ installed
- OpenClaw CLI installed (`npm i -g openclaw`)
- GitHub repo created (private recommended)

### 2. Clone & Configure
```bash
cd ~/.openclaw/workspace
# Copy improved scripts
cp scripts/backup_openclaw_improved.sh ~/backup.sh
chmod +x ~/backup.sh

# Edit config
nano ~/backup.sh
# Set: GIT_REPO="git@github.com:yourusername/your-repo.git"
# Set: TELEGRAM_CHAT_ID=your_chat_id
# Set: OPENCLAW_TOKEN=your_gateway_token
```

### 3. Schedule Cron (every 5 minutes)
```bash
crontab -e
# Add:
*/5 * * * * /home/youruser/backup.sh >> /tmp/backup.log 2>&1
```

### 4. Systemd Gateway (Self-healing)
```bash
# Copy service file
sudo cp systemd/openclaw-gateway.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable openclaw-gateway
sudo systemctl start openclaw-gateway
# Check status:
sudo systemctl status openclaw-gateway
```

### 5. Telegram Bot Token
Add to `openclaw.json`:
```json
{
  "channels": {
    "telegram": {
      "botToken": "YOUR_BOT_TOKEN"
    }
  }
}
```
Then use `safe-config-update-improved.sh`:
```bash
./scripts/safe-config-update-improved.sh '.channels.telegram.botToken' '"YOUR_TOKEN"' -r
```

### 6. LLM Fallback Configuration
Create `config-templates/llm-providers.json`:
```json
{
  "providers": [
    {
      "name": "openrouter",
      "priority": 1,
      "models": ["openrouter/stepfun/step-3.5-flash:free"],
      "fallback": true
    },
    {
      "name": "google_ai_studio",
      "priority": 2,
      "apiKey": "${GOOGLE_AI_STUDIO_KEY}",
      "models": ["gemini-1.5-pro"],
      "fallback": true
    }
  ],
  "strategy": "auto_failover"
}
```

Set environment variable:
```bash
export GOOGLE_AI_STUDIO_KEY="your_key_here"
```

---

## 🔧 Usage

### Daily Operations
- **Check status**: `openclaw status` or `systemctl status openclaw-gateway`
- **Manual backup**: `~/backup.sh`
- **Edit config safely**:
  ```bash
  ./scripts/safe-config-update-improved.sh '.gateway.port' '18790' -r
  ```
- **Restore from backup**:
  ```bash
  ./scripts/restore_from_github.sh --date 2026-02-25
  ```

### Memory Logging
The `memory-logger.sh` script auto-logs every conversation. In your agent code:
```bash
./scripts/memory-logger.sh "Amit" "Kya kar rahe ho?"
```
(OpenClaw agents can call this via `exec` tool)

---

## 🔐 Security

- **Never commit secrets**: `openclaw.json` stays local; only workspace files go to Git
- **Encrypt sensitive backups**: Use `age` or `gpg` in backup script (optional)
- **SSH keys**: Use deploy keys for GitHub access (no personal keys)
- **Token rotation**: Change gateway token monthly via `openclaw gateway token --rotate`

---

## 📊 Health Dashboard

OpenClaw gateway exposes `/health` endpoint:
```
http://127.0.0.1:18789/health
```
Returns JSON:
```json
{
  "status": "healthy",
  "uptime": 86400,
  "connectedChannels": ["telegram"],
  "activeSessions": 1,
  "lastBackup": "2026-02-28T09:50:00Z"
}
```

---

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| Gateway not starting | `sudo systemctl restart openclaw-gateway` |
| Backup failing | Check `/tmp/backup.log` for errors |
| Git push fails | Verify SSH key, repo permissions |
| Telegram not sending | Check bot token, chat_id, gateway connectivity |
| LLM unavailable | Check provider API keys, fallback config |

---

## 📈 Comparison: Lucy vs Jarvis Edition

| Feature | Lucy | Jarvis (Improved) |
|---------|------|-------------------|
| Backup interval | 5 min | 5 min (configurable) |
| Memory format | Summary | Full transcript |
| LLM providers | Single (OpenRouter) | Multi-provider auto-failover |
| Error handling | Basic | Comprehensive with retries |
| Notifications | Simple | Rich with context |
| Config edits | Manual | Safe tool with diff |
| Self-healing | Systemd | Systemd + watchdog + alerts |
| Security | Good | Better (encryption optional, no secrets in Git) |
| Monitoring | None | Health endpoint + logs |

---

## 📝 Notes

- All scripts are idempotent—safe to re-run
- Backups are compressed and deduped
- Memory files use Asia/Kolkata timezone (Amit's tz)
- Agent prefix: `🐶Lucy:` was used; now adapted to your identity
- Always test restore: `./scripts/restore_from_github.sh --dry-run`

---

**Made with 💙 by Jarvis — Because we're the best.**
