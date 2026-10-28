# Requirements

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.1-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

## System

| Requirement | Details |
|-------------|---------|
| **OS** | Debian 11+ / Ubuntu 20.04+ (with apt) |
| **Docker** | 20.10+ |
| **Docker Compose** | v2 (plugin, not standalone `docker-compose`) |
| **Root access** | For the bouncer package, `setup-bouncer` and firewall checks |
| **`/var/log/auth.log`** | Must exist, see below |

## Mailcow

- Mailcow runs via the official `docker-compose.yml`.
- Default container names, as used in `acquis.yaml`:

```
mailcowdockerized-nginx-mailcow-1
mailcowdockerized-postfix-mailcow-1
mailcowdockerized-dovecot-mailcow-1
mailcowdockerized-netfilter-mailcow-1
```

CrowdSec does **not** join the Mailcow network. The network name does not matter.

## auth.log for SSH protection

Debian 12 and newer log SSH only to journald. CrowdSec reads `/var/log/auth.log`, and the bind mount fails on purpose if the file is missing:

```bash
ls -l /var/log/auth.log || apt install rsyslog
```

An empty file created with `touch` does not help: nothing writes SSH logins into it. To skip SSH protection, see [Missing log files](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/TROUBLESHOOTING.md#missing-log-files).

## CrowdSec already installed on the host

You can run this stack next to a CrowdSec package on the host. There is no port clash: the host package listens on `127.0.0.1:8080`, the container publishes its LAPI on `127.0.0.1:8082`. The two instances are independent and do not share decisions.

A host firewall bouncer talks to exactly one LAPI:

- `./crowdsec.sh setup-bouncer` registers the bouncer at the **container** and rewrites `api_url` and `api_key` in `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`. An existing bouncer is repointed away from the host instance (backup: `.bak`).
- To keep the bouncer on the host instance, do not run `setup-bouncer`. Bans from the container are then not enforced by the firewall.
- `crowdsec.sh health` checks the container LAPI (port 8082) and the container's bouncer list. With the bouncer on the host instance, it can report problems that do not exist.

## Reverse proxy

If a reverse proxy sits in front of Mailcow, read [Mailcow behind a reverse proxy](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/TROUBLESHOOTING.md#mailcow-behind-a-reverse-proxy) first. Otherwise CrowdSec may ban the proxy.

## How to check

```bash
docker --version
docker compose version
docker ps --format '{{.Names}}' | grep mailcow
iptables --version   # see [[nftables vs iptables]]
```
