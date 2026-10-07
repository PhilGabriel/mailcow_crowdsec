# Troubleshooting

---

## I locked myself out

**Symptom:** Your own IP was banned and you can no longer reach the server.

**If you still have console/KVM access (e.g., via your hosting provider):**

```bash
# Remove the ban on your IP
docker exec crowdsec-mailcow cscli decisions delete --ip YOUR_IP

# Verify
docker exec crowdsec-mailcow cscli decisions list | grep YOUR_IP
```

**If even SSH is blocked** (bouncer runs on host, not in Docker):

```bash
# From KVM console, stop the bouncer temporarily:
systemctl stop crowdsec-firewall-bouncer

# Remove the ban:
docker exec crowdsec-mailcow cscli decisions delete --ip YOUR_IP

# Restart the bouncer:
systemctl start crowdsec-firewall-bouncer
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

Whitelisted IPs will appear in metrics as "Lines whitelisted" but will never trigger a ban.

---

## CrowdSec container won't start

**Symptom:** `docker compose up -d` fails or the container exits immediately.

**Check the logs:**
```bash
docker logs crowdsec-mailcow 2>&1 | tail -30
```

**Common causes:**

| Error in logs | Fix |
|---|---|
| `no such file or directory: /var/log/auth.log` | See [Missing log files](#missing-log-files) |
| `acquis.yaml: no such file or directory` | Run `docker compose` from inside the cloned repo directory |
| `bind source path does not exist: /var/log/auth.log` | See [Missing log files](#missing-log-files) |
| Permission denied on Docker socket | CrowdSec needs to run as root or have Docker socket access |

---

## Missing log files

**Symptom:**
```
no such file or directory: /var/log/auth.log
```

Debian 12+ and some container-based VPS log SSH only to journald and have no `/var/log/auth.log`.

**Option A** — Install rsyslog, which writes the file:
```bash
apt install rsyslog
```

An empty file created with `touch` does not help: nothing writes SSH logins into it.

**Option B** — Remove the SSH log source from `acquis.yaml` if you don't need SSH protection:
```yaml
# Comment out or remove the SSH section:
# filenames:
#   - /var/log/auth.log
# labels:
#   type: syslog
```

Also remove the `/var/log/auth.log` bind mount (the `type: bind` block) from `docker-compose.yml`.

---

## Mailcow container names don't match

**Symptom:** CrowdSec starts but `cscli metrics show acquisition` shows no lines read for Postfix, Dovecot, etc.

**Check your actual container names:**
```bash
docker ps --format '{{.Names}}' | grep mailcow
```

**Fix:** Update `acquis.yaml` to match your container names exactly:

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

**Check the bouncer service:**
```bash
systemctl status crowdsec-firewall-bouncer
journalctl -u crowdsec-firewall-bouncer --no-pager -n 30
```

**Common causes:**

| Error | Fix |
|---|---|
| `unauthorized` or `403` | Wrong API key — regenerate (see below) |
| `connection refused` on port 8082 | CrowdSec container is not running or not yet healthy |
| `api_url` empty or wrong | Edit `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml` |

**Regenerate the bouncer key:**
```bash
sudo ./crowdsec.sh setup-bouncer
```

Or manually:
```bash
# Delete old
docker exec crowdsec-mailcow cscli bouncers delete firewall-bouncer

# Create new
docker exec crowdsec-mailcow cscli bouncers add firewall-bouncer
# → Paste key into /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml

systemctl restart crowdsec-firewall-bouncer
```

---

## No bans are being created

**Symptom:** CrowdSec runs, logs are being read, but `cscli decisions list` is always empty.

This is normal if no attack patterns have been detected yet. CrowdSec requires a threshold of events before triggering a ban (e.g., 5 failed logins within a time window).

**Check what is being detected:**
```bash
# Recent alerts (lower threshold than bans)
docker exec crowdsec-mailcow cscli alerts list

# Log processing stats — "Lines poured to bucket" = events matched a scenario
docker exec crowdsec-mailcow cscli metrics show acquisition
```

**If "Lines parsed" is 0 for a service:**
→ Check [Logs are not being parsed](#logs-are-not-being-parsed).

---

## No log lines read at all

**Symptom:** `cscli metrics show acquisition` lists no `docker:` sources.

CrowdSec reads container logs through `crowdsec-socket-proxy`. Check its log for denied requests:

```bash
docker logs crowdsec-socket-proxy 2>&1 | grep -E " 403 |ALERT"
```

| Finding | Fix |
|---|---|
| `403` on `/containers/.../logs` | `ALLOW_LOGS: 1` is missing in `docker-compose.yml` |
| `cannot create receiving socket ... [:::2375]` | Host has IPv6 disabled and `DISABLE_IPV6: 1` is missing |
| Container keeps restarting | Check `docker logs crowdsec-socket-proxy` for the cause |

---

## Mailcow behind a reverse proxy

**Symptom:** Bans hit the reverse proxy IP, or webmail stops working for everyone.

Mailcow's nginx logs the address of the connecting peer. Behind a reverse proxy that is the proxy, so CrowdSec sees every web request coming from one IP. Mail ports (SMTP, IMAP) usually bypass the proxy and are unaffected.

**1. Whitelist the proxy IP** (always): add it to the whitelist file, see [Whitelisting your IPs](#whitelisting-your-ips). Without this step, one attacker can get the proxy banned.

**2. Restore client IPs in Mailcow's nginx** (optional): with the nginx `real_ip` module (`set_real_ip_from <proxy IP>;` and `real_ip_header X-Forwarded-For;`), Mailcow logs the client IP again and the HTTP scenarios work. Where Mailcow loads custom nginx config depends on your Mailcow version. Check the Mailcow documentation before you change it.

**3. Where the ban takes effect:** the firewall bouncer drops packets by source IP. If the proxy runs on another machine, packets reach Mailcow from the proxy, and a ban on the client IP blocks nothing for web traffic. Then the ban has to happen on the proxy host, for example with a second bouncer there.

---

## Logs are not being parsed

**Symptom:** `cscli metrics show acquisition` shows many "Lines unparsed" for a service.

> **Note:** CrowdSec has no parsers for Rspamd and SOGo, so this project does not read their logs. Failed logins there reach CrowdSec through netfilter-mailcow bans (`Guezli/mailcow-f2b-bans`).

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

**Check the bouncer service:**
```bash
systemctl status crowdsec-firewall-bouncer
journalctl -u crowdsec-firewall-bouncer --no-pager -n 20
```

**Check the firewall:**
```bash
iptables -S INPUT | grep -i crowdsec
iptables -S DOCKER-USER | grep -i crowdsec
```

**Common causes:**
- SSH is blocked, but SMTP/IMAP/webmail are not → `DOCKER-USER` is missing from `iptables_chains` in `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`. Docker-published ports bypass the `INPUT` chain. Add the chain and restart the bouncer.
- Bouncer service not running → `systemctl start crowdsec-firewall-bouncer`
- Bouncer not receiving decisions → API key issue (see above)
- Wrong firewall backend → see [nftables systems](#nftables-instead-of-iptables)

---

## nftables instead of iptables

Modern Debian 11+ / Ubuntu 22.04+ may use nftables as the default firewall backend.

**Check which backend your system uses:**
```bash
iptables --version
# "iptables v1.8.x (nf_tables)" → nftables backend
# "iptables v1.8.x (legacy)"    → iptables backend
```

**If you need to switch**, uninstall the iptables bouncer and install the nftables one:

```bash
apt remove crowdsec-firewall-bouncer-iptables
apt install crowdsec-firewall-bouncer-nftables
# → Update /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml with your API key
systemctl enable --now crowdsec-firewall-bouncer
```

The nftables bouncer hooks into `input` and `forward` by default, so it also covers Docker-published ports.

---

## CrowdSec is using too much CPU

**Symptom:** `crowdsec-mailcow` container consumes high CPU continuously.

**Common causes:**

1. **Ongoing attack** — many log events being generated:
   ```bash
   docker exec crowdsec-mailcow cscli alerts list --limit 5
   ```

2. **SQLite not in WAL mode**. `docker-compose.yml` sets `USE_WAL: "true"` since v0.2.0-alpha. Check:
   ```bash
   docker exec crowdsec-mailcow grep use_wal /etc/crowdsec/config.yaml
   # → use_wal: true
   ```

3. **Large initial log catch-up** — CrowdSec reads from the end of existing files. Resolves itself.

---

## Bans disappear after reboot

**Symptom:** Active bans in `cscli decisions list` are gone after a server restart.

This is expected — CrowdSec bans are time-limited (default 4 hours) and stored in the database volume. Unexpired bans survive container restarts as long as the volume persists.

```bash
docker volume ls | grep crowdsec
docker volume inspect mailcow_crowdsec_crowdsec-db
```

---

## Check overall health

Full status overview:

```bash
./crowdsec.sh health
```

Or manually:

```bash
# Container
docker compose ps

# LAPI
curl -sf http://127.0.0.1:8082/v1/heartbeat && echo "LAPI OK"

# Bouncer service
systemctl status crowdsec-firewall-bouncer

# Bouncer connection
docker exec crowdsec-mailcow cscli bouncers list

# CAPI (community API)
docker exec crowdsec-mailcow cscli capi status

# Active local bans (add -a to include the community blocklist)
docker exec crowdsec-mailcow cscli decisions list

# Full metrics
docker exec crowdsec-mailcow cscli metrics
```
