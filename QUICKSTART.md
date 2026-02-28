# 🚀 Quick Start — Jarvis OpenClaw Setup

**Goal:** Get your improved backup & monitoring system running in 15 minutes.

---

## Prerequisites Check

- [ ] Node.js 20+ installed (`node -v`)
- [ ] `openclaw` CLI installed (`openclaw --version`)
- [ ] GitHub account with a new repo created (keep it private)
- [ ] Telegram bot token ready (from @BotFather)
- [ ] Your chat ID (send a message to @userinfobot)

---

## Step 1: Configure SSH for GitHub (one-time)

```bash
# If you don't have SSH key:
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/id_ed25519

# Add public key to GitHub: copy ~/.ssh/id_ed25519.pub
# GitHub → Settings → SSH and GPG keys → New SSH key
```

---

## Step 2: Clone Backup Repo & Set Variables

```bash
cd ~/.openclaw/workspace

# Set these in your shell or add to ~/.bashrc / ~/.zshrc:
export GIT_REPO="git@github.com:YOUR_USER/YOUR_REPO.git"
export TELEGRAM_CHAT_ID="YOUR_CHAT_ID"
export OPENCLAW_TOKEN="8e25c23bbae32955a783916068267e38698dcd5e380835b3"
```

---

## Step 3: Test Backup Script

```bash
chmod +x ~/.openclaw/workspace/scripts/backup_openclaw_improved.sh

# Dry run first (will fail if GIT_REPO not set, but checks syntax):
GIT_REPO="git@github.com:YOUR_USER/YOUR_REPO.git" \
TELEGRAM_CHAT_ID="YOUR_CHAT_ID" \
OPENCLAW_TOKEN="YOUR_TOKEN" \
~/backup.sh 2>&1 | tail -20
```

If all goes well, you'll see:
```
✓ Backup created: backup_2026-02-28_101530.tar.gz
✓ Backup pushed to GitHub
Backup completed successfully in 45s
```

---

## Step 4: Schedule Cron (Auto-backup every 5 min)

```bash
crontab -e
# Add this line (replace path if different):
*/5 * * * * /home/Administrator/backup.sh >> /tmp/backup.log 2>&1
```

Verify:
```bash
crontab -l
```

---

## Step 5: Enable Self-Healing Gateway (systemd)

```bash
# Copy service file (need admin/sudo):
sudo cp ~/.openclaw/workspace/systemd/openclaw-gateway.service /etc/systemd/system/

# Reload and enable:
sudo systemctl daemon-reload
sudo systemctl enable openclaw-gateway
sudo systemctl start openclaw-gateway

# Check status:
sudo systemctl status openclaw-gateway

# You should see: active (running)
```

---

## Step 6: Configure Telegram Bot in OpenClaw

```bash
cd ~/.openclaw/workspace
./scripts/safe-config-update-improved.sh '.channels.telegram.botToken' '"YOUR_BOT_TOKEN"' -r
```

This will:
1. Backup your current `openclaw.json`
2. Update the token
3. Restart gateway automatically

---

## Step 7: Verify End-to-End

1. **Send a message to your bot** on Telegram
2. **Check response** — you should get a reply
3. **Wait 5 minutes** — you should get a backup notification
4. **Check GitHub** — new commit should appear with memory file
5. **View memory file** on GitHub: `memory/2026-02-28.md`
   - Should show full transcript with timestamps in 12hr Asia/Kolkata

---

## Step 8: Health Monitoring (Optional)

Set up cron for health checks every 15 minutes:

```bash
crontab -e
*/15 * * * * /home/Administrator/.openclaw/workspace/scripts/health-monitor.sh >> /tmp/health.log 2>&1
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Permission denied` on scripts | `chmod +x ~/.openclaw/workspace/scripts/*.sh` |
| `GIT_REPO not set` | Export it in shell or edit backup script |
| `cron: can't open /tmp/backup.log` | Ensure /tmp is writable |
| `Telegram not sending` | Check bot token, chat_id, gateway status |
| `Gateway won't start` | `sudo journalctl -u openclaw-gateway -f` |
| `Backup fails to push` | Test SSH: `ssh -T git@github.com` |

---

## 🎯 You're Done!

Your OpenClaw instance now has:

✅ Auto-backup every 5 min to GitHub  
✅ Full verbatim conversation logs  
✅ Self-healing gateway (systemd)  
✅ Telegram notifications  
✅ Health monitoring  
✅ Multi-provider LLM fallback ready  
✅ Safe config editing tool  

**Now relax — the system's got your back.**

---

**Need help?** Check README.md for detailed docs.
