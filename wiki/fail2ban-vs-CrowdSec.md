# fail2ban vs CrowdSec

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

Mailcow ships its own fail2ban-style ban engine: the `netfilter-mailcow` container. This project does **not** replace it. Both run side by side.

## Who does what

| | netfilter-mailcow | CrowdSec (this project) |
|---|---|---|
| **Detection** | Mailcow's own log patterns | Hub parsers and scenarios |
| **Covers** | Postfix, Dovecot, SOGo, Mailcow UI, Rspamd UI | Postfix, Dovecot, Nginx, SSH, plus netfilter bans |
| **Blocklist** | IPs that attacked *your* server | Plus the community blocklist |
| **Firewall** | own `MAILCOW` chain | ipset/nftables sets via the host bouncer |
| **Configuration** | Mailcow admin UI | YAML, hub, `cscli` |
| **Dashboard** | Mailcow UI | Optional: [app.crowdsec.net](https://app.crowdsec.net) |
| **API** | Mailcow API | LAPI (REST) |

## Why run both?

- `mailcow.conf` has no switch to disable netfilter-mailcow, and other Mailcow services depend on it.
- netfilter-mailcow covers logins CrowdSec cannot parse. `Guezli/mailcow-f2b-feed` turns those bans into CrowdSec decisions.
- CrowdSec adds SSH and Nginx scenarios and the community blocklist.

## fail2ban in general vs CrowdSec

| | fail2ban | CrowdSec |
|---|---|---|
| **Language** | Python | Go |
| **Rules** | Regex jails | Hub with maintained parsers, scenarios, collections |
| **Shared intelligence** | No | Yes, attackers are shared with the community |
| **Blocking** | iptables rule per IP | ipset/nftables sets |
| **Docker** | Needs log file mounts | Reads container logs, here through a read-only socket proxy |

## When CrowdSec adds little

- The server sees few attacks, and netfilter-mailcow is enough.
- You cannot install a host package (the bouncer).
- Your Mailcow setup uses heavily customised log formats.

## Trying it out

Installation and [[Uninstall]] leave Mailcow untouched. See [[Installation]].
