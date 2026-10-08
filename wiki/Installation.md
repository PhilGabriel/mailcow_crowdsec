# Installation

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

The full guide with explanations is [INSTALL.md](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/INSTALL.md) in the repository.

## Summary

1. **Check prerequisites**: container names, `/var/log/auth.log`, reverse proxy. See [[Requirements]].
2. **Clone**: `git clone https://github.com/PhilGabriel/mailcow_crowdsec.git && cd mailcow_crowdsec`
3. **Configure**: `cp .env.example .env` and set `TZ` if needed.
4. **Start CrowdSec and the socket proxy**: `docker compose up -d`
5. **Add the CrowdSec apt repository**: `curl -s https://install.crowdsec.net | sh`
6. **Install the bouncer**: `apt install crowdsec-firewall-bouncer-iptables` (or `-nftables`, see [[nftables vs iptables]])
7. **Connect the bouncer**: `sudo ./crowdsec.sh setup-bouncer`
8. **Enable at boot**: `systemctl enable crowdsec-firewall-bouncer`
9. **Verify**: `sudo ./crowdsec.sh health`

Leave Mailcow's `netfilter-mailcow` running. `mailcow.conf` has no switch to disable it, and CrowdSec imports its bans.

## What setup-bouncer does

1. Registers `firewall-bouncer` in CrowdSec and creates an API key. An existing registration is replaced.
2. Writes `api_url: http://127.0.0.1:8082/` and `api_key` into `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml` (backup: `.bak`).
3. Adds `DOCKER-USER` to `iptables_chains` in iptables mode. Without it, bans block SSH but not SMTP, IMAP or webmail.
4. Restarts the bouncer and lists the registered bouncers.

## Next steps

- [[Whitelist Setup]]: protect your own IPs
- [[CrowdSec Central API]]: optional dashboard
- [[Helper Script]]: command reference
