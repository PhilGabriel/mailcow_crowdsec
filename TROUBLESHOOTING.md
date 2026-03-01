# Troubleshooting

---

## I locked myself out

**Symptom:** Your own IP was banned and you can no longer reach the server.

**If you still have console/KVM access (e.g., via your hosting provider):**

```bash
# Find and remove the ban on your IP
docker exec crowdsec-mailcow cscli decisions delete --ip YOUR_IP

# Verify it's removed
docker exec crowdsec-mailcow cscli decisions list | grep YOUR_IP
```

**If even SSH is blocked** (bouncer blocks at iptables level):

```bash
# From the console, temporarily flush the CrowdSec iptables chains
iptables -F CROWDSEC_CHAIN   # actual chain name may vary
# or simply restart the bouncer which clears its rules on start:
docker restart crowdsec-firewall-bouncer
```

**Prevent this in the future** — whitelist your IPs. See [Whitelisting your IPs](#whitelisting-your-ips).

---

## Whitelisting your IPs

To prevent your own IPs, monitoring systems, or internal networks from being banned:

**1. Create a whitelist file:**

```bash
docker exec crowdsec-mailcow bash -c 'cat > /etc/crowdsec/parsers/s02-enrich/my-whitelist.yaml << EOF
name: local/my-whitelist
description: "Whitelist trusted IPs"
whitelist:
  reason: "trusted network"
  ip:
    - "YOUR_PUBLIC_IP"
    - "YOUR_SECOND_IP"
  cidr:
    - "10.0.0.0/8"
    - "172.16.0.0/12"
    - "192.168.0.0/16"
EOF'
```

**2. Restart CrowdSec:**

```bash
docker compose restart crowdsec
```

**3. Verify:**

```bash
docker exec crowdsec-mailcow cscli metrics | grep whitelisted
```

Whitelisted IPs will still appear in logs as "Lines whitelisted" but will never trigger a ban.

---

## CrowdSec container won't start

**Symptom:** `docker compose up -d crowdsec` fails or the container exits immediately.

**Check the logs:**
```bash
docker logs crowdsec-mailcow 2>&1 | tail -30
```

**Common causes:**

| Error in logs | Fix |
|---|---|
| `network mailcowdockerized_mailcow-network not found` | See [Wrong network name](#wrong-mailcow-network-name) |
| `no such file or directory: /var/log/auth.log` | See [Missing log files](#missing-log-files) |
| `acquis.yaml: no such file or directory` | Make sure you're running `docker compose` from inside the cloned repo directory |
| Permission denied on `/var/lib/docker/containers` | CrowdSec needs to run as root or have access to the Docker socket |

---

## Wrong Mailcow network name

**Symptom:**
```
network mailcowdockerized_mailcow-network declared as external, but could not be found
```

**Fix:** Find your actual network name and update `docker-compose.yml`:

```bash
docker network ls | grep mailcow
# Example output: mailcow_mailcow-network
```

Edit `docker-compose.yml`, change the `networks` section at the bottom:

```yaml
networks:
  mailcow-network:
    external: true
    name: mailcow_mailcow-network  # ← your actual name here
```

---

## Missing log files

**Symptom:**
```
no such file or directory: /var/log/auth.log
```

**Fix:** Some systems (especially container-based VPS or custom setups) don't have `/var/log/auth.log`.

Option A — Create it:
```bash
touch /var/log/auth.log
```

Option B — Remove the SSH log source from `acquis.yaml` if you don't need SSH protection:
```yaml
# Comment out or remove the SSH section:
# filenames:
#   - /var/log/auth.log
# labels:
#   type: syslog
```

Also remove the volume mount from `docker-compose.yml`:
```yaml
# Remove this line:
# - /var/log/auth.log:/var/log/auth.log:ro
```

---

## Mailcow container names don't match

**Symptom:** CrowdSec starts but `cscli metrics show acquisition` shows no lines read for Postfix, Dovecot, etc.

**Check your actual container names:**
```bash
docker ps --format '{{.Names}}' | grep mailcow
```

**Fix:** Update `acquis.yaml` to match your container names exactly. Example for a custom install:

```yaml
source: docker
container_name:
  - my-postfix-container   # ← replace with your actual name
labels:
  type: postfix
```

Restart after changes:
```bash
docker compose restart crowdsec
```

---

## Firewall bouncer not connecting

**Symptom:** `cscli bouncers list` shows `firewall-bouncer` with an old or missing "Last API pull".

**Check:**
```bash
docker logs crowdsec-firewall-bouncer 2>&1 | tail -20
```

**Common causes:**

| Error | Fix |
|---|---|
| `unauthorized` or `403` | Wrong API key in `.env` — regenerate (see below) |
| `connection refused` on port 8082 | CrowdSec container is not running or not yet healthy |
| Bouncer container exits immediately | Check logs with `docker logs crowdsec-firewall-bouncer` |

**Regenerate the bouncer key:**
```bash
# Delete old key
docker exec crowdsec-mailcow cscli bouncers delete firewall-bouncer

# Create new key
docker exec crowdsec-mailcow cscli bouncers add firewall-bouncer
# → Update CROWDSEC_FIREWALL_BOUNCER_KEY in .env

docker compose restart crowdsec-firewall-bouncer
```

---

## No bans are being created

**Symptom:** CrowdSec runs, logs are being read, but `cscli decisions list` is always empty.

This is normal behavior if no attack patterns have been detected yet. CrowdSec requires a threshold of events before triggering a ban (e.g., 5 failed logins within a time window).

**Check what is being detected:**
```bash
# Recent alerts (lower threshold than bans)
docker exec crowdsec-mailcow cscli alerts list

# Log processing stats — "Lines poured to bucket" = events matched a scenario
docker exec crowdsec-mailcow cscli metrics show acquisition
```

**If "Lines parsed" is 0 for a service:**
→ The parser for that service is either not installed or the log format doesn't match. Check [Logs are not being parsed](#logs-are-not-being-parsed).

---

## Logs are not being parsed

**Symptom:** `cscli metrics show acquisition` shows many "Lines unparsed" for a service.

> **Note:** Rspamd and SOGo logs will always show as 100% unparsed — there are no official CrowdSec parsers for these services yet. This is expected and does not affect the protection of other services.

**Check installed parsers and collections:**
```bash
docker exec crowdsec-mailcow cscli collections list
docker exec crowdsec-mailcow cscli parsers list
```

**Update and upgrade the hub:**
```bash
docker exec crowdsec-mailcow cscli hub update
docker exec crowdsec-mailcow cscli hub upgrade
docker compose restart crowdsec
```

---

## iptables rules are not being created

**Symptom:** Bans appear in `cscli decisions list` but IPs are not actually blocked.

**Check the firewall bouncer logs:**
```bash
docker logs crowdsec-firewall-bouncer 2>&1 | tail -20
```

**Check if iptables rules exist:**
```bash
iptables -L INPUT -n | grep -i crowdsec
```

**Common causes:**
- The bouncer container is not running (`docker compose ps`)
- The bouncer is not receiving decisions (API key issue — see above)
- Your system uses **nftables** instead of iptables — see [nftables systems](#nftables-instead-of-iptables)

---

## nftables instead of iptables

Modern Debian 11+/Ubuntu 22.04+ may use nftables as the default firewall backend. The bouncer supports both.

**Check which backend your system uses:**
```bash
# If this returns rules, you're using iptables:
iptables -L INPUT -n 2>/dev/null | head -5

# If iptables shows "nf_tables" in the version, it's nftables behind the scenes:
iptables --version
# → "iptables v1.8.x (nf_tables)" = nftables backend
```

**To switch the bouncer to nftables mode**, uncomment in `docker-compose.yml`:

```yaml
environment:
  MODE: nftables
```

Then restart:
```bash
docker compose restart crowdsec-firewall-bouncer
```

---

## CrowdSec is using too much CPU

**Symptom:** `crowdsec-mailcow` container consumes high CPU continuously.

**Common causes:**

1. **Ongoing attack** — An active attacker generates many log events:
   ```bash
   docker exec crowdsec-mailcow cscli alerts list --limit 5
   ```

2. **SQLite not in WAL mode** — Improves database performance under load:
   ```bash
   docker exec crowdsec-mailcow sqlite3 /var/lib/crowdsec/data/crowdsec.db "PRAGMA journal_mode=WAL;"
   ```

3. **Very large log files** — CrowdSec only reads new lines from the current end of the file. This resolves itself after the initial catch-up.

---

## Bans disappear after reboot

**Symptom:** Active bans in `cscli decisions list` are gone after a server restart.

This is expected — CrowdSec bans are time-limited (default 4 hours) and stored in the database volume. If the volume is persisted, existing unexpired bans survive restarts.

Make sure your volumes are properly configured (not using `--rm` when starting containers):

```bash
docker volume ls | grep crowdsec
docker volume inspect mailcow_crowdsec_crowdsec-db
```

---

## Check overall health

Run this to get a full status overview:

```bash
# Container status
docker compose ps

# All active bans
docker exec crowdsec-mailcow cscli decisions list -a

# CAPI (community API) connectivity
docker exec crowdsec-mailcow cscli capi status

# Bouncer connectivity
docker exec crowdsec-mailcow cscli bouncers list

# Hub component status
docker exec crowdsec-mailcow cscli hub list

# Full metrics
docker exec crowdsec-mailcow cscli metrics
```

Or use the included helper script:

```bash
./crowdsec.sh status
```
