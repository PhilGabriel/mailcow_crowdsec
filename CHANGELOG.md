# Changelog

## Unreleased

### Fixed

- SSH detection stopped after the first logrotate of `auth.log`, because the single-file bind mount kept the old inode. `/var/log` is now mounted read-only as a directory (at `/var/log/host`), so the container sees all host logs. The container now also starts without `auth.log`; `./crowdsec.sh health` warns in that case. If you keep a locally changed `acquis.yaml`, change the SSH path to `/var/log/host/auth.log`; the old path no longer exists in the container.

### Changed

- `tests/enforcement.sh` sends real traffic in all modes: a connection from the banned IP to a Docker-published port must work before the ban, fail after it and work again after the unban.
- New test `tests/rotation.sh`: SSH detection survives a logrotate of `auth.log`.
- Docs: socket proxy scope corrected. It gives read-only access to the logs and metadata (including environment variables) of all containers on the host, not to the logs of the Mailcow containers only. No write access, no file access.
- Docs: window without CrowdSec bans documented (after a reboot, or while the CrowdSec container or the bouncer is not running).

## 0.4.0-beta (2026-11-13)

Hosts that already run CrowdSec get a second bouncer for this container's bans.

### Added

- `./crowdsec.sh setup-bouncer --second` for hosts that already run CrowdSec: a second firewall bouncer instance (own nftables tables, own systemd unit) that enforces the container's bans and leaves the existing bouncer untouched. Until now, bans from this container (`postfix-spam`, `postscreen-rbl`, ...) were not enforced on such hosts.
- `crowdsec.sh status` shows the second bouncer.
- `tests/enforcement.sh second` and a CI matrix entry: the ban must appear in the `crowdsec-mailcow` table with the forward hook, and the first bouncer's config must stay byte-identical.
- Wiki page "Second Bouncer", plus pointers in INSTALL, TROUBLESHOOTING and the other wiki pages.

### Changed

- CrowdSec image v1.8.1 → v1.8.2 (pinned by digest). Versions in README and wiki updated.

### Fixed

- shellcheck SC2329 for the trap functions in `tests/enforcement.sh` and `tests/upgrade.sh` (newer shellcheck; the lint job had been failing on `main`).

## 0.3.0-beta (2026-10-28)

First beta. What changed since 0.2.1-alpha is below. Known gaps are listed in the README under "Known limitations".

### Added

- `tests/enforcement.sh` and a CI job: a ban decision must become an nftables rule that includes the `forward` hook, and must disappear when the decision is deleted. It also exercises `setup-bouncer`.
- `tests/enforcement.sh` runs for both the nftables and the iptables bouncer (`DOCKER-USER` chain).
- `tests/upgrade.sh` and a CI job: start the last release, create a ban and files, switch to the current compose file on the same volumes.
- Dependabot for `docker-compose` and GitHub Actions.
- README section "Verified with".

### Security

- Images are pinned by digest (`tag@sha256:…`).

### Changed

- Docs: section for hosts that already run CrowdSec (Requirements wiki page), and a warning in CONTRIBUTING.md not to run `tests/run.sh` on a Mailcow host.

## 0.2.1-alpha (2026-10-28)

### Changed

- Socket proxy image 3.4.6 → 3.4.7.

### Security

- `crowdsec.sh setup-bouncer` kept the backup of the bouncer config (`.bak`, contains the previous API key) with default permissions. It now keeps the original mode (`cp -p`).
- `crowdsec.sh unban` rejects arguments that are not an IP address or range. `setup-bouncer` rejects a bouncer key with unexpected characters before it writes the config.

### Fixed

- `tests/run.sh` refuses to run if containers with the names it uses already exist. The test creates dummy containers named like the real Mailcow ones and removes them with `docker rm -f` on exit, which would delete a production Mailcow stack.

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
