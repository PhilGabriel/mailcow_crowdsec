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

CrowdSec and fail2ban can conflict (both try to manage iptables rules and both react to the same log events). Disable fail2ban first:

```bash
# In /opt/mailcow-dockerized/mailcow.conf, set:
SKIP_FAIL2BAN=y

# Then apply:
cd /opt/mailcow-dockerized
docker compose down
docker compose up -d
```

Verify fail2ban is no longer running:

```bash
docker ps | grep fail2ban
# → should return nothing
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

Edit `.env` and set your timezone:

```
TZ=Europe/Berlin
```

Leave `CROWDSEC_FIREWALL_BOUNCER_KEY` empty for now — it will be generated in Step 4.

---

## Step 3 — Start CrowdSec

```bash
docker compose up -d crowdsec
```

Wait ~30 seconds for CrowdSec to initialize and become healthy, then verify:

```bash
docker compose ps
# → crowdsec-mailcow should show "Up (healthy)"
```

Check the logs:

```bash
docker logs crowdsec-mailcow 2>&1 | tail -20
```

You should see lines like:
```
level=info msg="start monitoring" container_name=mailcowdockerized-postfix-mailcow-1
level=info msg="start monitoring" container_name=mailcowdockerized-dovecot-mailcow-1
...
```

Check that log sources are active:

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
# Container status
docker compose ps

# Active bans (may be empty right after install — that's normal)
docker exec crowdsec-mailcow cscli decisions list

# Log processing stats
docker exec crowdsec-mailcow cscli metrics show acquisition

# Or use the helper script:
./crowdsec.sh status
```

---

## Step 7 — Test detection

To confirm CrowdSec is actually detecting and blocking attacks:

**Option A: Check if community blocklist is active**

```bash
# After a few minutes, the community blocklist should be loaded:
docker exec crowdsec-mailcow cscli decisions list -a | head -20
```

**Option B: Simulate a brute-force attack (from a different IP/machine)**

> ⚠️ Do NOT run this from your own server — you will ban yourself.

From another machine, generate failed SSH logins:

```bash
for i in $(seq 1 10); do
  ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no fakeuser@YOUR_SERVER_IP 2>/dev/null
done
```

Then check on your server:

```bash
docker exec crowdsec-mailcow cscli decisions list
# → The attacking IP should appear with scenario "crowdsecurity/ssh-bf" or "ssh-slow-bf"
```

**Option C: Verify iptables rules are being created**

```bash
iptables -L INPUT -n | grep -i crowdsec
# → Should show a jump to a CROWDSEC chain
```

---

## Step 8 (optional) — Whitelist your IPs

Prevent your own IPs from being accidentally banned:

```bash
docker exec crowdsec-mailcow bash -c 'cat > /etc/crowdsec/parsers/s02-enrich/my-whitelist.yaml << EOF
name: local/my-whitelist
description: "Whitelist trusted IPs"
whitelist:
  reason: "trusted network"
  ip:
    - "YOUR_PUBLIC_IP"
  cidr:
    - "10.0.0.0/8"
    - "172.16.0.0/12"
    - "192.168.0.0/16"
EOF'
docker compose restart crowdsec
```

---

## Step 9 (optional) — Enroll with CrowdSec Central API

Enrolling gives you a web dashboard at [app.crowdsec.net](https://app.crowdsec.net) with alerts, ban history, and remote management.

**1.** Register a free account at [app.crowdsec.net](https://app.crowdsec.net)

**2.** Go to **Security Engines → Add** and copy your enrollment key

**3.** Add to `.env`:
```
CROWDSEC_ENROLL_KEY=your_enrollment_key_here
CROWDSEC_INSTANCE_NAME=my-mailcow-server
```

**4.** Uncomment the enrollment lines in `docker-compose.yml` under `environment`:
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

**Update hub components** (parsers, scenarios, collections):

```bash
docker exec crowdsec-mailcow cscli hub update
docker exec crowdsec-mailcow cscli hub upgrade

# Or use the helper script:
./crowdsec.sh update
```

**Update Docker images:**

```bash
docker compose pull
docker compose up -d
```

> After updating Docker images, you may need to regenerate the bouncer key if the CrowdSec database volume was reset.

---

## Backup

The CrowdSec database (bans, alerts, local config) lives in the `crowdsec-db` Docker volume:

```bash
# Find volume location
docker volume inspect mailcow_crowdsec_crowdsec-db --format '{{ .Mountpoint }}'

# Backup
docker exec crowdsec-mailcow sqlite3 /var/lib/crowdsec/data/crowdsec.db ".backup /tmp/crowdsec-backup.db"
docker cp crowdsec-mailcow:/tmp/crowdsec-backup.db ./crowdsec-backup.db
```

---

## Uninstall

To completely remove CrowdSec and go back to Mailcow's built-in fail2ban:

**1. Stop and remove CrowdSec containers:**

```bash
cd mailcow_crowdsec
docker compose down
```

**2. Remove Docker volumes (deletes all CrowdSec data):**

```bash
docker volume rm mailcow_crowdsec_crowdsec-db mailcow_crowdsec_crowdsec-config mailcow_crowdsec_firewall-bouncer-config
```

**3. Verify iptables rules were cleaned up:**

```bash
iptables -L INPUT -n | grep -i crowdsec
# → Should return nothing. If rules remain:
# iptables -D INPUT -j CROWDSEC_CHAIN (adjust chain name)
```

**4. Re-enable Mailcow fail2ban:**

```bash
# In /opt/mailcow-dockerized/mailcow.conf, set:
SKIP_FAIL2BAN=n

# Then apply:
cd /opt/mailcow-dockerized
docker compose down
docker compose up -d
```

**5. Verify fail2ban is running again:**

```bash
docker ps | grep fail2ban
```
