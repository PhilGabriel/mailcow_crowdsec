# Quick Start

> ℹ️ **BETA** — Detection, ban enforcement (nftables and iptables) and the upgrade from the last release are covered by CI. Known gaps: see [Known limitations](https://github.com/PhilGabriel/mailcow_crowdsec#known-limitations). Test in a non-production environment first.
>
> Wiki state: **v0.3.0-beta** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

For readers who know CrowdSec and Docker. Check [[Requirements]] first.

```bash
# Clone
git clone https://github.com/PhilGabriel/mailcow_crowdsec.git
cd mailcow_crowdsec && cp .env.example .env

# SSH log source needs this file
ls -l /var/log/auth.log || apt install -y rsyslog

# Start CrowdSec + socket proxy
docker compose up -d

# Install the bouncer from the CrowdSec repository
curl -s https://install.crowdsec.net | sh
apt install -y crowdsec-firewall-bouncer-iptables   # or -nftables

# Register, configure (incl. DOCKER-USER), restart
./crowdsec.sh setup-bouncer
systemctl enable crowdsec-firewall-bouncer

# Verify
./crowdsec.sh health
```

Run the commands as root. Mailcow itself needs no change.
