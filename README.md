# CrowdSec for Mailcow

> ⚠️ **ALPHA — EXPERIMENTAL SOFTWARE**
>
> This project is in early development. It has been tested in a specific production environment but is **not yet considered stable for general use**. Configuration, file structure, and behaviour may change between versions without notice. Use at your own risk — always test in a non-production environment first and keep backups of your Mailcow data.

---

> **Drop-in replacement for Mailcow's built-in fail2ban** — powered by [CrowdSec](https://crowdsec.net/), a collaborative, open-source security engine.

CrowdSec monitors your Mailcow logs in real time, detects brute-force attacks, spam relaying attempts, and other abuse patterns, and blocks offending IPs via iptables/nftables. Unlike fail2ban, CrowdSec additionally benefits from a shared community blocklist with millions of known malicious IPs, blocking threats before they even attempt to attack your server.

---

## Why CrowdSec instead of fail2ban?

| | fail2ban | CrowdSec |
|---|---|---|
| **Detection** | Local log analysis only | Local analysis + shared community intelligence |
| **Blocklist** | Only IPs that attacked *your* server | Millions of known-bad IPs from the CrowdSec network |
| **Performance** | Single-threaded, regex-heavy | Go-based, multi-threaded, compiled parsers |
| **Blocking** | iptables rules per IP | ipset/nftables sets — efficient with thousands of IPs |
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
  │  Log Processor   │        │  (community blocklist)   │
  │  + LAPI (Docker) │        └──────────────────────────┘
  └────────┬────────┘
           │  ban decisions via API (:8082)
           ▼
  ┌─────────────────┐
  │  Firewall       │
  │  Bouncer (host) │──► iptables / nftables DROP
  └─────────────────┘
```

- **CrowdSec (Docker)** reads container logs, detects attacks, serves ban decisions via LAPI
- **Firewall Bouncer (host)** is a systemd service that queries the LAPI and manages iptables/nftables rules
- **Community Blocklist** automatically pulls known-bad IPs from the CrowdSec network

> **Why is the bouncer on the host?** The firewall bouncer needs direct access to the system's iptables/nftables. Running it as a host service is the [official CrowdSec recommendation](https://docs.crowdsec.net/u/bouncers/firewall/) — it's more reliable than running it in a privileged container.

---

## Features

- ✅ Monitors all Mailcow services: Postfix, Dovecot, Nginx, Rspamd, SOGo
- ✅ SSH brute-force protection included
- ✅ Community threat intelligence (shared blocklist)
- ✅ Blocks at iptables/nftables level — traffic never reaches your services
- ✅ Supports both iptables and nftables
- ✅ IP whitelisting for trusted networks
- ✅ LAPI healthcheck and logging limits built in
- ✅ Helper script for common operations
- ✅ Optional: web dashboard via [app.crowdsec.net](https://app.crowdsec.net)
- ✅ Replaces fail2ban with zero changes to Mailcow itself

---

## Quick Start

```bash
git clone https://github.com/PhilGabriel/mailcow_crowdsec.git
cd mailcow_crowdsec
cp .env.example .env

# Start CrowdSec
docker compose up -d

# Install firewall bouncer on host
apt install crowdsec-firewall-bouncer-iptables

# Generate API key and configure bouncer
docker exec crowdsec-mailcow cscli bouncers add firewall-bouncer
# → Paste the key into /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
# → Set api_url: http://127.0.0.1:8082/

systemctl enable --now crowdsec-firewall-bouncer

# Check status
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
./crowdsec.sh health      # Check LAPI, CAPI, and bouncer
```

---

## Repository structure

```
mailcow_crowdsec/
├── docker-compose.yml      # CrowdSec container (LAPI + log processor)
├── acquis.yaml             # Log sources (Mailcow containers + SSH)
├── crowdsec.sh             # Helper script for common operations
├── .env.example            # Environment variables
├── README.md               # This file
├── INSTALL.md              # Full installation guide (incl. uninstall)
├── TROUBLESHOOTING.md      # Common problems and solutions
└── LICENSE                 # MIT
```

---

## Requirements

| Requirement | Details |
|-------------|---------|
| OS | Debian 11+ / Ubuntu 20.04+ (with apt) |
| Docker | 20.10+ |
| Docker Compose | v2 (plugin) |
| Mailcow | Running via the official `docker-compose.yml` |
| Mailcow network | `mailcowdockerized_mailcow-network` (default) |
| Root access | Required for firewall bouncer installation |

---

## Documentation

📖 **[Full documentation in the Wiki](https://github.com/PhilGabriel/mailcow_crowdsec/wiki)** — Installation, Configuration, Troubleshooting, Architecture, and more.

---

## Disclaimer

THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND. THE AUTHORS ARE NOT RESPONSIBLE FOR ANY DAMAGE, DATA LOSS, SERVICE OUTAGE, OR SECURITY INCIDENTS RESULTING FROM THE USE OF THIS SOFTWARE. **You are solely responsible for testing, validating, and securing your own infrastructure.** This project is not affiliated with or endorsed by [Mailcow](https://mailcow.email/) or [CrowdSec](https://crowdsec.net/).

---

## License

MIT — see [LICENSE](LICENSE)
