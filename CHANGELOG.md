# Changelog

## 0.2.0-alpha (2026-10-07)

### Fixed

- **Bans did not block mail traffic (iptables bouncer).** Docker publishes the Mailcow ports, so SMTP, IMAP and webmail traffic passes the FORWARD path. The bouncer only hooked into `INPUT`. INSTALL.md now adds the `DOCKER-USER` chain.
- **Postfix logs were never parsed.** `type: postfix` set the program name to `postfix`, but `crowdsecurity/postfix-logs` expects `postfix/smtpd`. Postfix and Dovecot now use `type: syslog`, matching the syslog-ng output of the Mailcow containers.
- Docs referenced `SKIP_FAIL2BAN`, which does not exist in `mailcow.conf`. They now describe `netfilter-mailcow` correctly.
- Backup and WAL instructions called `sqlite3`, which the CrowdSec image does not contain.
- A missing `/var/log/auth.log` made Docker create a directory at that path. The bind mount now fails instead.
- `crowdsec.sh` works from any directory and detects a stopped container.

### Security

- CrowdSec no longer mounts the Docker socket. A read-only socket proxy (`lscr.io/linuxserver/socket-proxy`) allows only GET requests for container lists, logs, events and info. The `:ro` flag on a socket mount does not restrict the Docker API.
- CrowdSec left the Mailcow network. It needed no access to Redis, MySQL or other internal Mailcow services.
- Removed the unused `/var/lib/docker/containers` mount.

### Added

- netfilter-mailcow bans become CrowdSec decisions (`Guezli/mailcow-f2b-bans` parser, `Guezli/mailcow-f2b-feed` scenario, both community hub items). This covers failed logins in Mailcow UI, SOGo and Rspamd UI.
- `./crowdsec.sh setup-bouncer` registers the host bouncer, writes `api_url`, `api_key` and the `DOCKER-USER` chain, and restarts it.
- Integration test (`tests/run.sh`): starts the stack and dummy Mailcow containers, then expects alerts for Postfix, Dovecot, nginx and netfilter sample logs. Runs in GitHub Actions with shellcheck and `docker compose config`.
- TROUBLESHOOTING: reverse proxy setups, socket proxy errors.

### Removed

- Rspamd and SOGo log sources. CrowdSec has no parsers for them; they only cost CPU.

### Changed

- CrowdSec image v1.7.4 → v1.8.1.
- `USE_WAL: "true"` enables SQLite write-ahead logging.
- `crowdsec.sh status` and `bans` show local bans only. `bans --all` includes the community blocklist.
- `crowdsec.sh health` checks the `DOCKER-USER` chain and nftables.
- INSTALL.md adds the CrowdSec apt repository and an rsyslog note for Debian 12+.

### Upgrade from 0.1.0-alpha

1. `git pull && docker compose pull && docker compose up -d`
2. `sudo ./crowdsec.sh setup-bouncer` (new key, `DOCKER-USER` chain, restart)
3. Check: `./crowdsec.sh health`
4. Optional: `docker network rm mailcow_crowdsec_crowdsec-net` removes the old, now unused network.

## 0.1.0-alpha

Initial release.
