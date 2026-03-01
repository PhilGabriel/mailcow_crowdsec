# CrowdSec for Mailcow

> ⚠️ **ALPHA — EXPERIMENTAL SOFTWARE**
>
> This project is in early development. It has been tested in a specific production environment but is **not yet considered stable for general use**. Configuration, file structure, and behaviour may change between versions without notice. Use at your own risk — always test in a non-production environment first and keep backups of your Mailcow data.

---

> **Drop-in replacement for Mailcow's built-in fail2ban** — powered by [CrowdSec](https://crowdsec.net/), a collaborative, open-source security engine.

CrowdSec monitors your Mailcow logs in real time, detects brute-force attacks, spam relaying attempts, and other abuse patterns, and blocks offending IPs via iptables. Unlike fail2ban, CrowdSec additionally benefits from a shared community blocklist with millions of known malicious IPs, blocking threats before they even attempt to attack your server.

---

## Why CrowdSec instead of fail2ban?

| | fail2ban | CrowdSec |
|---|---|---|
| **Detection** | Local log analysis only | Local analysis + shared community intelligence |
| **Blocklist** | Only IPs that attacked *your* server | Millions of known-bad IPs from the CrowdSec network |
| **Performance** | Single-threaded, regex-heavy | Go-based, multi-threaded, compiled parsers |
| **Blocking** | iptables rules per IP | ipset/iptables — efficient even with thousands of IPs |
| **Dashboard** | CLI only | Optional web dashboard via [app.crowdsec.net](https://app.crowdsec.net) |
| **Ecosystem** | Regex jails | Hub with maintained parsers, scenarios, and collections |
| **Collaborative** | No | Yes — detected attackers are shared with the community |
| **API** | No | REST API (LAPI) for automation and integration |

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
  │  Bouncer        │──► iptables / nftables DROP
  └─────────────────┘
```

- **Log Processor** reads Docker container logs from all Mailcow services and SSH auth logs
- **LAPI (Local API)** manages decisions and exposes them to bouncers
- **Firewall Bouncer** translates ban decisions into iptables/nftables rules, blocking IPs at kernel level
- **Community Blocklist** automatically pulls known-bad IPs from the CrowdSec network (no account required)

---

## Features

- ✅ Monitors all Mailcow services: Postfix, Dovecot, Nginx, Rspamd, SOGo
- ✅ SSH brute-force protection included
- ✅ Community threat intelligence (shared blocklist)
- ✅ Blocks at iptables/nftables level — traffic never reaches your services
- ✅ Supports both iptables and nftables
- ✅ IP whitelisting for trusted networks
- ✅ Healthcheck and logging limits built in
- ✅ Helper script for common operations
- ✅ Optional: web dashboard via [app.crowdsec.net](https://app.crowdsec.net)
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

# Step 4: Check status
./crowdsec.sh status
```

→ See [INSTALL.md](INSTALL.md) for the full step-by-step guide with prerequisites, testing, and whitelisting.  
→ See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common problems and solutions.

---

## Helper script

```bash
./crowdsec.sh status      # Full status overview
./crowdsec.sh bans        # List active bans
./crowdsec.sh alerts      # Show recent alerts
./crowdsec.sh metrics     # Log processing stats
./crowdsec.sh unban IP    # Remove a ban
./crowdsec.sh whitelist   # Show whitelisted IPs
./crowdsec.sh update      # Update hub components
./crowdsec.sh logs        # Follow CrowdSec logs
./crowdsec.sh health      # Check CAPI + bouncer connectivity
```

---

## Repository structure

```
mailcow_crowdsec/
├── docker-compose.yml      # CrowdSec + Firewall Bouncer services
├── acquis.yaml             # Log sources (Mailcow containers + SSH)
├── crowdsec.sh             # Helper script for common operations
├── .env.example            # Required environment variables
├── README.md               # This file
├── INSTALL.md              # Full installation guide (incl. uninstall)
├── TROUBLESHOOTING.md      # Common problems and solutions
└── LICENSE                 # MIT
```

---

## Requirements

| Requirement | Details |
|-------------|---------|
| OS | Linux with iptables or nftables |
| Docker | 20.10+ |
| Docker Compose | v2 (plugin) |
| Mailcow | Running via the official `docker-compose.yml` |
| Mailcow network | `mailcowdockerized_mailcow-network` (default) |

---

## License

MIT — see [LICENSE](LICENSE)
