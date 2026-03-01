# Troubleshooting

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
| `unauthorized` or `403` | Wrong API key in `.env` — regenerate with `cscli bouncers add firewall-bouncer` |
| `connection refused` on port 8082 | CrowdSec container is not running or not yet ready |
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

**For Rspamd and SOGo:** These services have limited official parser support. Unparsed lines from these are expected and do not prevent the rest from working.

---

## iptables rules are not being created

**Symptom:** Bans appear in `cscli decisions list` but IPs are not actually blocked.

**Check the firewall bouncer logs:**
```bash
docker logs crowdsec-firewall-bouncer 2>&1 | tail -20
```

**Check if iptables rules exist:**
```bash
iptables -L INPUT -n | grep CROWDSEC
# or
iptables -L INPUT -n | grep DROP
```

**Common causes:**
- The bouncer container is not running (`docker compose ps`)
- The bouncer is not receiving decisions (API key issue — see above)
- iptables is not available in the network namespace (ensure `privileged: true` and `network_mode: host` in `docker-compose.yml`)

---

## CrowdSec is using too much CPU

**Symptom:** `crowdsec-mailcow` container consumes high CPU continuously.

**Common causes:**

1. **Very large log files being tailed** — CrowdSec only reads new log lines (from the current end of the file), so large existing files are not re-read after restart. This resolves itself.

2. **Ongoing attack** — An active attacker generates many log events. Check:
   ```bash
   docker exec crowdsec-mailcow cscli alerts list --limit 5
   ```

3. **SQLite not in WAL mode** — CrowdSec logs a warning on startup if SQLite WAL mode is not enabled. Enable it:
   ```bash
   docker exec crowdsec-mailcow sqlite3 /var/lib/crowdsec/data/crowdsec.db "PRAGMA journal_mode=WAL;"
   ```

---

## Bans disappear after reboot

**Symptom:** Active bans in `cscli decisions list` are gone after a server restart.

This is expected — CrowdSec bans are time-limited (default 4 hours) and stored in the database volume. If the volume is persisted, existing unexpired bans survive restarts.

Make sure your volumes are properly configured (not using `--rm` when starting containers).

**Check volume status:**
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

# Metrics overview
docker exec crowdsec-mailcow cscli metrics
```
