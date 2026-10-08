# CrowdSec for Mailcow

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

CrowdSec protection for Mailcow. It runs **alongside** Mailcow's built-in ban engine (netfilter-mailcow) and needs no changes to Mailcow itself.

CrowdSec reads the Mailcow logs through a read-only Docker socket proxy, detects attacks and adds the community blocklist. A firewall bouncer on the host drops banned IPs in iptables or nftables, including the `DOCKER-USER` chain that Mailcow's published ports pass through.

---

## Pages

### Getting Started
- [[Requirements]]: what you need before installing
- [[Installation]]: step-by-step summary
- [[Quick Start]]: all commands in one block

### Configuration
- [[Acquis Configuration]]: log sources, container names, netfilter-mailcow feed
- [[Whitelist Setup]]: protect your own IPs
- [[CrowdSec Central API]]: optional web dashboard
- [[nftables vs iptables]]: choose the bouncer package

### Operations
- [[Helper Script]]: `crowdsec.sh` command reference
- [[Updating]]: image, hub and bouncer updates, upgrade from 0.1.0-alpha
- [[Backup and Restore]]: save the CrowdSec volumes
- [[Uninstall]]: remove everything

### Troubleshooting
- [[Common Problems]]: symptoms and fixes
- [[Lockout Recovery]]: you banned yourself

### Background
- [[Architecture]]: components, socket proxy, log flow
- [[fail2ban vs CrowdSec]]: how CrowdSec relates to netfilter-mailcow
- [[Disclaimer]]

### Project
- [Contributing](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CONTRIBUTING.md): checks and rules for pull requests
- [Security policy](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/SECURITY.md): report vulnerabilities privately
- [Code of conduct](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CODE_OF_CONDUCT.md)
- [Accessibility](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/ACCESSIBILITY.md)
