# TODO — Jarvis OpenClaw Setup

**Status:** In Progress | **Started:** 2026-02-28

---

## 🎯 Immediate Tasks

- [ ] Create new GitHub repo (private) for backups
- [ ] Configure SSH deploy key for GitHub access
- [ ] Set environment variables:
  - `GIT_REPO` (repo URL)
  - `TELEGRAM_CHAT_ID` (your chat ID)
  - `OPENCLAW_TOKEN` (gateway token)
- [ ] Test backup script manually: `~/backup.sh`
- [ ] Add to crontab: `*/5 * * * * /home/Administrator/backup.sh`
- [ ] Verify first backup pushed to GitHub
- [ ] Test Telegram notification (with/without attachment)

## 🔧 Systemd & Self-Healing

- [ ] Install systemd service: `sudo cp systemd/openclaw-gateway.service /etc/systemd/system/`
- [ ] `sudo systemctl daemon-reload`
- [ ] `sudo systemctl enable openclaw-gateway`
- [ ] `sudo systemctl start openclaw-gateway`
- [ ] Verify: `sudo systemctl status openclaw-gateway`
- [ ] Test self-healing: kill gateway process, check if it restarts

## 🔐 Security

- [ ] Ensure `openclaw.json` contains real tokens (not in Git)
- [ ] Rotate gateway token if exposed: `openclaw gateway token --rotate`
- [ ] Set up SSH deploy keys (no personal keys in production)
- [ ] Consider encrypting backup dir with `age` (optional)

## 🧠 LLM Configuration

- [ ] Choose fallback provider (Google AI Studio or local Ollama)
- [ ] If Google AI Studio: get API key, set `GOOGLE_AI_STUDIO_KEY`
- [ ] Update `config-templates/llm-providers.json` to reflect chosen setup
- [ ] Integrate provider selection into agent config
- [ ] Test failover: disable primary provider, verify fallback triggers

## 📊 Monitoring

- [ ] Deploy health endpoint monitoring
- [ ] Set up alerts for:
  - Gateway down
  - Backup failures
  - Disk space > 80%
  - LLM provider failures
- [ ] Optional: Add Prometheus metrics exporter

## 📝 Logging Improvements

- [ ] Ensure `memory-logger.sh` is hooked into agent execution
- [ ] Verify full transcript format in daily memory files
- [ ] Test that 12hr Asia/Kolkata timestamps are correct
- [ ] Confirm "🤖 Jarvis:" prefix (or current agent name) appears consistently

## 🧪 Testing

- [ ] Restore from backup test: `./scripts/restore_from_github.sh --dry-run`
- [ ] Config rollback test: use `safe-config-update-improved.sh`, verify rollback
- [ ] Simulate failure: stop gateway, confirm systemd restarts
- [ ] Simulate Git outage: ensure backup script fails gracefully
- [ ] Notification test: send manual Telegram message via gateway

## 🚀 Future Enhancements

- [ ] Multi-agent support (different personas per context)
- [ ] Encrypted backups (age/gpg)
- [ ] Smart memory deduplication (avoid Git noise)
- [ ] Config diff viewer in Telegram bot
- [ ] Web dashboard for health & backups
- [ ] Backup retention policy (prune old backups)
- [ ] Performance metrics collection

---

**Note:** This is a living document. Update as you progress.
