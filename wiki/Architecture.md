# Architecture

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

## Components

1. **Socket proxy** (`crowdsec-socket-proxy`, Docker): read-only filter in front of the Docker socket. It allows GET requests for container lists, logs, events and info only.
2. **CrowdSec** (`crowdsec-mailcow`, Docker): reads container logs through the proxy, detects attacks and serves ban decisions through its Local API (LAPI).
3. **Firewall bouncer** (host, systemd): polls the LAPI and manages iptables or nftables rules.
4. **netfilter-mailcow** (Mailcow): keeps running. CrowdSec imports its bans.

```
Mailcow Containers (Postfix, Dovecot, Nginx, netfilter)
         │  logs via read-only socket proxy
         ▼
  ┌─────────────────┐        ┌──────────────────────────┐
  │   CrowdSec      │◄──────►│  CrowdSec Central API    │
  │  Log Processor  │        │  (community blocklist)   │
  │  + LAPI (Docker)│        └──────────────────────────┘
  └────────┬────────┘
           │  ban decisions via API (127.0.0.1:8082)
           ▼
  ┌─────────────────┐
  │  Firewall       │
  │  Bouncer (host) │──► iptables (INPUT + DOCKER-USER) / nftables (input + forward)
  └─────────────────┘
```

## Why a socket proxy?

Access to `/var/run/docker.sock` equals root on the host. The `:ro` mount flag does not restrict the Docker API. The proxy runs with `POST: 0`, a read-only root filesystem and `no-new-privileges`. It sits on an internal network (`socket-proxy`) without outside access. Only CrowdSec talks to it.

## Networks

| Network | Members | Purpose |
|---------|---------|---------|
| `socket-proxy` (internal) | proxy, CrowdSec | Docker API requests |
| `default` | CrowdSec | Central API, hub downloads |

CrowdSec is **not** on the Mailcow network. It needs no access to Redis, MySQL or other internal Mailcow services.

## Ports

| Port | Binding | Purpose |
|------|---------|---------|
| 8082 | `127.0.0.1` only | LAPI for the host bouncer |
| 8080 | inside the container | LAPI |
| 2375 | `socket-proxy` network only | Docker API through the proxy |

## Why is the bouncer on the host?

The bouncer changes iptables or nftables rules. Running it as a host service is the [official CrowdSec recommendation](https://docs.crowdsec.net/u/bouncers/firewall/). It needs no privileged container, and systemd restarts it.

## Why DOCKER-USER?

Docker publishes the Mailcow ports. Incoming SMTP, IMAP and webmail traffic therefore passes the `FORWARD` path, not `INPUT`. The iptables bouncer must hook into `DOCKER-USER` as well. `./crowdsec.sh setup-bouncer` adds it. The nftables bouncer hooks into `input` and `forward` by default.

## Log flow

1. Mailcow containers write logs to Docker's log driver.
2. CrowdSec reads them through the socket proxy and picks up new containers through Docker events.
3. Parsers extract IPs, users and actions.
4. Scenarios detect patterns, for example repeated failed logins.
5. CrowdSec stores decisions in its database (SQLite with WAL).
6. The bouncer polls the LAPI and adds banned IPs to its ipset or nftables set.

## Hub items

| Item | Protects against |
|------|-----------------|
| `crowdsecurity/nginx` | Web brute force, path scanning |
| `crowdsecurity/base-http-scenarios` | Generic HTTP attacks |
| `crowdsecurity/postfix` | SMTP brute force, relay abuse |
| `crowdsecurity/dovecot` | IMAP/POP3 brute force |
| `crowdsecurity/sshd` | SSH brute force |
| `Guezli/mailcow-f2b-bans` + `-feed` | Mailcow UI, SOGo and Rspamd UI logins, via netfilter-mailcow |

## Community blocklist

CrowdSec connects to the Central API (CAPI) by default and receives a list of known-bad IPs. No account is needed. `./crowdsec.sh bans --all` shows these entries.

## Testing

`tests/run.sh` starts the stack with dummy containers that use the Mailcow names and print sample logs. The test passes when CrowdSec raises an alert for each attacker IP. GitHub Actions runs it with shellcheck and `docker compose config` on every pull request.
