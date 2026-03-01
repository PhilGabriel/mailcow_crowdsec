# CrowdSec for Mailcow

Drop-in replacement for Mailcow's built-in fail2ban using [CrowdSec](https://crowdsec.net/).

CrowdSec monitors all Mailcow services (Postfix, Dovecot, Nginx, Rspamd, SOGo) and blocks attackers via iptables. It also benefits from the CrowdSec community threat intelligence feed.

## What's included

- **CrowdSec** — log processor + LAPI + community blocklist
- **Firewall Bouncer** — blocks IPs via iptables/nftables
- **acquis.yaml** — log acquisition for all Mailcow containers + SSH

Collections installed automatically:
- `crowdsecurity/nginx` — webmail/admin brute-force
- `crowdsecurity/postfix` — SMTP abuse
- `crowdsecurity/dovecot` — IMAP/POP3 brute-force
- `crowdsecurity/sshd` — SSH brute-force
- `crowdsecurity/base-http-scenarios` — generic HTTP attacks

## Prerequisites

- Mailcow running via Docker Compose (default network: `mailcowdockerized_mailcow-network`)
- Docker + Docker Compose v2

## Setup

**1. Clone and configure**

```bash
git clone https://github.com/PhilGabriel/mailcow_crowdsec.git
cd mailcow_crowdsec
cp .env.example .env
```

**2. Start CrowdSec (first boot — no bouncer key yet)**

```bash
docker compose up -d crowdsec
```

**3. Generate the bouncer API key**

```bash
docker exec crowdsec-mailcow cscli bouncers add firewall-bouncer
```

Copy the key into your `.env`:

```
CROWDSEC_FIREWALL_BOUNCER_KEY=<paste key here>
```

**4. Start the firewall bouncer**

```bash
docker compose up -d crowdsec-firewall-bouncer
```

**5. Verify**

```bash
# Check running containers
docker compose ps

# Show active bans
docker exec crowdsec-mailcow cscli decisions list

# Show recent alerts
docker exec crowdsec-mailcow cscli alerts list

# Check metrics
docker exec crowdsec-mailcow cscli metrics
```

## Optional: Enroll with CrowdSec Central API

Register at [app.crowdsec.net](https://app.crowdsec.net), create an instance, and add your enrollment key to `.env`:

```
CROWDSEC_ENROLL_KEY=your_key_here
CROWDSEC_INSTANCE_NAME=my-mailcow
```

Then enroll:

```bash
docker exec crowdsec-mailcow cscli console enroll ${CROWDSEC_ENROLL_KEY}
docker compose restart crowdsec
```

## Mailcow: Disable built-in fail2ban

If Mailcow's own fail2ban is active, disable it to avoid conflicts:

```bash
# In mailcow.conf
SKIP_FAIL2BAN=y

# Then restart
cd /opt/mailcow-dockerized && docker compose down && docker compose up -d
```

## Troubleshooting

```bash
# View CrowdSec logs
docker logs crowdsec-mailcow -f

# Check which log sources are being read
docker exec crowdsec-mailcow cscli metrics show acquisition

# Update hub (parsers, scenarios)
docker exec crowdsec-mailcow cscli hub update && cscli hub upgrade
```
