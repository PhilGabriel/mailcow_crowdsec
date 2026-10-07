# Changelog

## 0.2.0-alpha (2026-10-07)

### Fixed

- **Bans did not block mail traffic (iptables bouncer).** Docker publishes the Mailcow ports, so SMTP, IMAP and webmail traffic passes the FORWARD path. The bouncer only hooked into `INPUT`. INSTALL.md now adds the `DOCKER-USER` chain.
- **Postfix logs were never parsed.** `type: postfix` set the program name to `postfix`, but `crowdsecurity/postfix-logs` expects `postfix/smtpd`. Postfix and Dovecot now use `type: syslog`, matching the syslog-ng output of the Mailcow containers.
- Docs referenced `SKIP_FAIL2BAN`, which does not exist in `mailcow.conf`. They now describe `netfilter-mailcow` correctly.
- Backup and WAL instructions called `sqlite3`, which the CrowdSec image does not contain.
- A missing `/var/log/auth.log` made Docker create a directory at that path. The bind mount now fails instead.
- `crowdsec.sh` works from any directory and detects a stopped container.

### Changed

- CrowdSec image v1.7.4 → v1.8.1.
- `USE_WAL: "true"` enables SQLite write-ahead logging.
- `crowdsec.sh status` and `bans` show local bans only. `bans --all` includes the community blocklist.
- `crowdsec.sh health` checks the `DOCKER-USER` chain and nftables.
- INSTALL.md adds the CrowdSec apt repository and an rsyslog note for Debian 12+.

### Upgrade from 0.1.0-alpha

1. `git pull && docker compose pull && docker compose up -d`
2. iptables bouncer: add `DOCKER-USER` to `iptables_chains` in `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`, then `systemctl restart crowdsec-firewall-bouncer`.
3. Check: `./crowdsec.sh health`

## 0.1.0-alpha

Initial release.
