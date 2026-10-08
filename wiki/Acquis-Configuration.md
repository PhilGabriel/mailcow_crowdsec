# Acquis Configuration

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

`acquis.yaml` tells CrowdSec which logs to read. It is mounted read-only as `/etc/crowdsec/acquis.yaml`. Every Docker source reads through the socket proxy (`docker_host: tcp://socket-proxy:2375`).

## Default sources

| Source | Container | Label `type` | Hub items |
|--------|-----------|---------------|-----------|
| Nginx (webmail, admin UI) | `nginx-mailcow` | `nginx` | `crowdsecurity/nginx`, `crowdsecurity/base-http-scenarios` |
| Dovecot (IMAP/POP3) | `dovecot-mailcow` | `syslog` | `crowdsecurity/dovecot` |
| Postfix (SMTP) | `postfix-mailcow` | `syslog` | `crowdsecurity/postfix` |
| netfilter-mailcow bans | `netfilter-mailcow` | `mailcow-f2b` | `Guezli/mailcow-f2b-bans`, `Guezli/mailcow-f2b-feed` |
| SSH | `/var/log/auth.log` (file) | `syslog` | `crowdsecurity/sshd` |

### Why `syslog` for Postfix and Dovecot

Mailcow writes both logs through syslog-ng in syslog format. `type: syslog` lets `crowdsecurity/syslog-logs` extract the program name (`postfix/smtpd`, `dovecot`), which the parsers filter on. Version 0.1.0-alpha used `type: postfix`, and Postfix lines were never parsed.

### netfilter-mailcow feed

CrowdSec has no parsers for the Mailcow UI, SOGo or Rspamd UI. netfilter-mailcow already bans failed logins there. `Guezli/mailcow-f2b-bans` parses its ban lines, and `Guezli/mailcow-f2b-feed` turns each into a CrowdSec decision. Both are community hub items.

### Rspamd and SOGo

Version 0.2.0-alpha removed both log sources. No CrowdSec parser exists for them, so they only cost CPU. Their failed logins arrive through the netfilter-mailcow feed.

## Adjusting container names

```bash
docker ps --format '{{.Names}}' | grep mailcow
```

Edit the names in `acquis.yaml`. Keep `docker_host` and the `type` label:

```yaml
source: docker
docker_host: tcp://socket-proxy:2375
container_name:
  - your-postfix-container
  - your-dovecot-container
labels:
  type: syslog
```

Then:

```bash
docker compose restart crowdsec
docker exec crowdsec-mailcow cscli metrics show acquisition
```

## Adding a log source

Add a YAML document separated by `---`. The `type` label must match an installed parser:

```bash
docker exec crowdsec-mailcow cscli parsers list
```

New hub items go into `COLLECTIONS`, `PARSERS` or `SCENARIOS` in `docker-compose.yml`. If you contribute a source, add a sample log to the integration test, see [Contributing](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CONTRIBUTING.md#adding-a-log-source-or-parser).
