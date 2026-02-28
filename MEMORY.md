# MEMORY.md — Curated Long-Term Memories

**Agent:** Jarvis 🤖  
**User:** Amit (Devlomatix Solutions)  
**Last updated:** 2026-02-28 (Asia/Kolkata)

---

## 👨‍👩‍👦 Family

- **User:** Amit
- **Wife:** Preeti
- **Son:** Laksh (nickname: Anshu)

## 🏢 Business

- **Company:** Devlomatix Solutions
- **Vertical(s):** Hospital CRM (Ashacarewell), Solar Panel Cleaning (planned)
- **GST:** One GSTIN covers all verticals; solar vertical will use SAC `99871` with 18% GST
- **Telegram:** Direct chat with Jarvis (workspace: J:)

## 🤖 Assistant Identity

- **Name:** Jarvis
- **Creature:** AI assistant
- **Vibe:** Helpful, competent, straightforward, not overly formal
- **Prefix:** 🤖 (emoji)
- **Address style:** Formal "aap" (not casual "tum")
- **Timezone:** Asia/Kolkata (UTC+5:30)

## 🛠️ Technical Setup (Current)

- **Gateway:** Local (127.0.0.1:18789), token auth
- **Backup system:** Improved scripts (every 5 min to GitHub)
  - Full verbatim transcript logging
  - 12-hour Asia/Kolkata timestamps
  - Telegram notifications (with attachment planned)
- **Memory format:** Daily logs (full transcript) + curated MEMORY.md
- **LLM:** OpenRouter (step-3.5-flash) + fallback providers configured
- **Self-healing:** Systemd + watchdog service (ready to deploy)
- **Health monitoring:** health-monitor.sh script

## 🔄 Previous Agent Reference (Lucy Backup)

- Lucy's repo: `amitvishwa19/lucy_openclaw` (cloned as `lucy_backup`)
- Lucy style: 🐶 prefix, chill vibe
- That system was operational but had issues with OpenRouter availability
- Backup system design reused and improved in current setup

## 📝 Preferences & Boundaries

- Chill but professional communication
- Proactive problem-solving
- Values continuity, automated state management
- Respectful address: always "aap", never "tum"
- Time always shown in Asia/Kolkata (12hr format)
- Full conversation verbatim logging required
- Backup notifications every 5 min (with full transcript attachment)

## ✅ Setup Status (2026-02-28)

- [x] Workspace bootstrap complete
- [x] Identity established (Jarvis 🤖)
- [x] User profile created (Amit, Kolkata, "aap" formal)
- [x] Lucy backup repo cloned and studied
- [x] Improved backup script created (`scripts/backup_openclaw_improved.sh`)
- [x] Safe config updater created (`scripts/safe-config-update-improved.sh`)
- [x] Memory logger created (`scripts/memory-logger.sh`)
- [x] Health monitor created (`scripts/health-monitor.sh`)
- [x] Systemd service file ready (`systemd/openclaw-gateway.service`)
- [x] Comprehensive README written
- [ ] GitHub repo created and configured
- [ ] Cron job scheduled (every 5 min)
- [ ] Systemd service enabled (self-healing)
- [ ] Telegram notifications fully tested
- [ ] LLM fallback integrated (Google AI Studio)
- [ ] Health dashboard endpoint monitoring

---

*This file is curated from daily logs. Update after major events.*
