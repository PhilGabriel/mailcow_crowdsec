# CrowdSec for Mailcow

> **Drop-in replacement for Mailcow's built-in fail2ban** — powered by [CrowdSec](https://crowdsec.net/), a collaborative, open-source security engine.

CrowdSec monitors your Mailcow logs in real time, detects brute-force attacks, spam relaying attempts, and other abuse patterns, and blocks offending IPs via iptables. Unlike fail2ban, CrowdSec additionally benefits from a shared community blocklist with millions of known malicious IPs, blocking threats before they even attempt to attack your server.

---

## How it works

```
Mailcow Containers (Postfix, Dovecot, Nginx, Rspamd, SOGo)
         │  logs via Docker socket
         ▼
  ┌─────────────────┐        ┌──────────────────────────┐
  │   CrowdSec      │◄──────►│  CrowdSec Central API    │
  │  Log Processor  │        │  (community blocklist)   │
  │  + LAPI         │        └──────────────────────────┘
  └────────┬────────┘
           │  ban decisions
           ▼
  ┌─────────────────┐
  │  Firewall       │
  │  Bouncer        │──► iptables DROP
  └─────────────────┘
```

- **Log Processor** reads Docker container logs from all Mailcow services and SSH auth logs
- **LAPI (Local API)** manages decisions and exposes them to bouncers
- **Firewall Bouncer** translates ban decisions into iptables rules, blocking IPs at kernel level
- **Community Blocklist** automatically pulls known-bad IPs from the CrowdSec network (no account required for basic use)

---

## Features

- ✅ Monitors all Mailcow services: Postfix, Dovecot, Nginx, Rspamd, SOGo
- ✅ SSH brute-force protection
- ✅ Community threat intelligence (shared blocklist with millions of IPs)
- ✅ Blocks at iptables level — offending traffic never reaches your services
- ✅ No credentials or account required for basic use
- ✅ Optional: enroll with [app.crowdsec.net](https://app.crowdsec.net) for a management dashboard
- ✅ Replaces fail2ban with zero changes to Mailcow itself

---

## Quick Start

```bash
git clone https://github.com/PhilGabriel/mailcow_crowdsec.git
cd mailcow_crowdsec
cp .env.example .env

# Step 1: Start CrowdSec
docker compose up -d crowdsec

# Step 2: Generate API key for the bouncer
docker exec crowdsec-mailcow cscli bouncers add firewall-bouncer
# → Copy the key into .env as CROWDSEC_FIREWALL_BOUNCER_KEY

# Step 3: Start the firewall bouncer
docker compose up -d crowdsec-firewall-bouncer
```

→ See [INSTALL.md](INSTALL.md) for the full step-by-step guide.  
→ See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) if something doesn't work.

---

## Repository structure

```
mailcow_crowdsec/
├── docker-compose.yml      # CrowdSec + Firewall Bouncer
├── acquis.yaml             # Log sources (all Mailcow services + SSH)
├── .env.example            # Required environment variables
├── README.md               # This file
├── INSTALL.md              # Full installation guide
└── TROUBLESHOOTING.md      # Common problems and solutions
```

---

## Requirements

| Requirement | Details |
|-------------|---------|
| OS | Debian/Ubuntu (iptables available) |
| Docker | 20.10+ |
| Docker Compose | v2 (plugin, not standalone) |
| Mailcow | Running via the official `docker-compose.yml` |
| Mailcow network | `mailcowdockerized_mailcow-network` (default name) |

---

## License

MIT
