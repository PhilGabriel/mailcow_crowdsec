# Installation Guide

This guide walks you through installing CrowdSec as a drop-in replacement for Mailcow's built-in fail2ban.

---

## Before you start

**1. Check your Mailcow network name**

```bash
docker network ls | grep mailcow
```

The default is `mailcowdockerized_mailcow-network`. If yours differs, update the `networks` section in `docker-compose.yml` accordingly.

**2. Check your Mailcow container names**

```bash
docker ps --format '{{.Names}}' | grep mailcow
```

Expected names (default Mailcow install):
```
mailcowdockerized-nginx-mailcow-1
mailcowdockerized-postfix-mailcow-1
mailcowdockerized-dovecot-mailcow-1
mailcowdockerized-rspamd-mailcow-1
mailcowdockerized-sogo-mailcow-1
```

If your names differ, update `acquis.yaml` with the correct names before proceeding.

**3. Disable Mailcow's built-in fail2ban**

CrowdSec and fail2ban can conflict. Disable fail2ban first:

```bash
# In /opt/mailcow-dockerized/mailcow.conf, set:
SKIP_FAIL2BAN=y

# Then apply:
cd /opt/mailcow-dockerized
docker compose down
docker compose up -d
```

---

## Step 1 — Clone the repository

```bash
git clone https://github.com/PhilGabriel/mailcow_crowdsec.git
cd mailcow_crowdsec
```

---

## Step 2 — Configure environment

```bash
cp .env.example .env
```

Set your timezone in `.env`:

```
TZ=Europe/Berlin
```

Leave `CROWDSEC_FIREWALL_BOUNCER_KEY` empty for now — it will be generated in Step 4.

---

## Step 3 — Start CrowdSec

```bash
docker compose up -d crowdsec
```

Wait ~15 seconds for CrowdSec to initialize, then verify:

```bash
docker logs crowdsec-mailcow 2>&1 | tail -20
```

You should see lines like:
```
level=info msg="start monitoring" container_name=mailcowdockerized-postfix-mailcow-1
level=info msg="start monitoring" container_name=mailcowdockerized-dovecot-mailcow-1
...
```

Check that all log sources are active:

```bash
docker exec crowdsec-mailcow cscli metrics show acquisition
```

---

## Step 4 — Generate the bouncer API key

```bash
docker exec crowdsec-mailcow cscli bouncers add firewall-bouncer
```

The command outputs a key like:
```
Api key for 'firewall-bouncer':

         abc123xyz...

Please keep this key since you will not be able to retrieve it!
```

Copy this key into your `.env` file:

```
CROWDSEC_FIREWALL_BOUNCER_KEY=abc123xyz...
```

---

## Step 5 — Start the firewall bouncer

```bash
docker compose up -d crowdsec-firewall-bouncer
```

Verify the bouncer connected successfully:

```bash
docker exec crowdsec-mailcow cscli bouncers list
```

You should see `firewall-bouncer` with a recent "Last API pull" timestamp.

---

## Step 6 — Verify everything works

```bash
# Active bans (may be empty right after install — that's normal)
docker exec crowdsec-mailcow cscli decisions list

# Recent detections
docker exec crowdsec-mailcow cscli alerts list

# Log processing stats
docker exec crowdsec-mailcow cscli metrics show acquisition

# Installed collections
docker exec crowdsec-mailcow cscli collections list
```

---

## Step 7 (optional) — Enroll with CrowdSec Central API

Enrolling gives you a web dashboard at [app.crowdsec.net](https://app.crowdsec.net) with alerts, ban history, and the ability to manage your instance remotely.

**1.** Register a free account at [app.crowdsec.net](https://app.crowdsec.net)

**2.** Go to **Security Engines → Add** and copy your enrollment key

**3.** Add to `.env`:
```
CROWDSEC_ENROLL_KEY=your_enrollment_key_here
CROWDSEC_INSTANCE_NAME=my-mailcow-server
```

**4.** Uncomment the two lines in `docker-compose.yml` under `environment`:
```yaml
ENROLL_KEY: "${CROWDSEC_ENROLL_KEY}"
ENROLL_INSTANCE_NAME: "${CROWDSEC_INSTANCE_NAME}"
```

**5.** Restart:
```bash
docker compose restart crowdsec
```

**6.** Accept the enrollment in the [app.crowdsec.net](https://app.crowdsec.net) dashboard

---

## Keeping CrowdSec updated

CrowdSec parsers, scenarios, and collections receive regular updates. Update the hub periodically:

```bash
docker exec crowdsec-mailcow cscli hub update
docker exec crowdsec-mailcow cscli hub upgrade
```

To update the Docker images:

```bash
docker compose pull
docker compose up -d
```
