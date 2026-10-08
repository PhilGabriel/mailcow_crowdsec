# CrowdSec for Mailcow

> ⚠️ **ALPHA — EXPERIMENTAL SOFTWARE**
>
> This project is in early development. It has been tested in a specific production environment but is **not yet considered stable for general use**. Configuration, file structure, and behaviour may change between versions without notice. Use at your own risk — always test in a non-production environment first and keep backups of your Mailcow data.

---

**Version:** 0.2.0-alpha · CrowdSec v1.8.1 · [Changelog](CHANGELOG.md)

> **CrowdSec protection for Mailcow**, running alongside Mailcow's built-in ban engine (netfilter-mailcow) — powered by [CrowdSec](https://crowdsec.net/), a collaborative, open-source security engine.

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
Mailcow Containers (Postfix, Dovecot, Nginx, netfilter)
         │  logs via read-only socket proxy
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

- **Socket proxy (Docker)** gives CrowdSec read access to container logs only. Direct Docker socket access would equal root on the host.
- **CrowdSec (Docker)** reads container logs, detects attacks, serves ban decisions via LAPI
- **Firewall Bouncer (host)** is a systemd service that queries the LAPI and manages iptables/nftables rules
- **Community Blocklist** automatically pulls known-bad IPs from the CrowdSec network

> **Why is the bouncer on the host?** The firewall bouncer needs direct access to the system's iptables/nftables. Running it as a host service is the [official CrowdSec recommendation](https://docs.crowdsec.net/u/bouncers/firewall/) — it's more reliable than running it in a privileged container.

---

## Features

- ✅ Monitors Postfix, Dovecot and Nginx directly
- ✅ Takes over netfilter-mailcow bans (Mailcow UI, SOGo, Rspamd UI logins)
- ✅ SSH brute-force protection included
- ✅ Community threat intelligence (shared blocklist)
- ✅ Blocks at iptables/nftables level — traffic never reaches your services
- ✅ Supports both iptables and nftables
- ✅ IP whitelisting for trusted networks
- ✅ LAPI healthcheck and logging limits built in
- ✅ Helper script for common operations, incl. one-command bouncer setup
- ✅ Docker socket behind a read-only proxy
- ✅ CI integration test against real CrowdSec
- ✅ Optional: web dashboard via [app.crowdsec.net](https://app.crowdsec.net)
- ✅ Zero changes to Mailcow itself

---

## Quick Start

```bash
git clone https://github.com/PhilGabriel/mailcow_crowdsec.git
cd mailcow_crowdsec
cp .env.example .env

# Start CrowdSec
docker compose up -d

# Install firewall bouncer on host (adds the CrowdSec apt repository first)
curl -s https://install.crowdsec.net | sh
apt install crowdsec-firewall-bouncer-iptables

# Register the bouncer, write its config (incl. DOCKER-USER chain), restart it
./crowdsec.sh setup-bouncer
systemctl enable crowdsec-firewall-bouncer

# Check status
./crowdsec.sh status
```

→ See [INSTALL.md](INSTALL.md) for the full step-by-step guide with prerequisites, testing, and whitelisting.  
→ See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common problems and solutions.

---

## Helper script

```bash
./crowdsec.sh status      # Full status overview
./crowdsec.sh bans        # List local bans (--all incl. community blocklist)
./crowdsec.sh alerts      # Show recent alerts
./crowdsec.sh metrics     # Log processing stats
./crowdsec.sh unban IP    # Remove a ban
./crowdsec.sh whitelist   # Show whitelisted IPs
./crowdsec.sh update      # Update hub components
./crowdsec.sh logs        # Follow CrowdSec logs
./crowdsec.sh health      # Check LAPI, CAPI, and bouncer
./crowdsec.sh setup-bouncer  # Register host bouncer and write its config
```

---

## Repository structure

```
mailcow_crowdsec/
├── docker-compose.yml      # CrowdSec + read-only Docker socket proxy
├── acquis.yaml             # Log sources (Mailcow containers + SSH)
├── crowdsec.sh             # Helper script for common operations
├── .env.example            # Environment variables
├── CHANGELOG.md            # Version history
├── README.md               # This file
├── INSTALL.md              # Full installation guide (incl. uninstall)
├── TROUBLESHOOTING.md      # Common problems and solutions
├── CONTRIBUTING.md         # Checks and rules for pull requests
├── SECURITY.md             # Supported versions, private vulnerability reports
├── CODE_OF_CONDUCT.md      # Contributor Covenant 2.1
├── ACCESSIBILITY.md        # Accessibility statement
├── tests/                  # Integration test (run.sh + sample logs)
├── wiki/                   # Wiki pages, synced to the GitHub wiki on merge
├── .github/workflows/      # CI: shellcheck, compose config, integration test, wiki sync
├── .github/ISSUE_TEMPLATE/ # Bug, feature and accessibility forms
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
