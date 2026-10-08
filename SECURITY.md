# Security Policy

## Supported versions

The project is alpha. Only the latest release gets fixes.

| Version | Supported |
|---|---|
| 0.2.x-alpha | Yes |
| 0.1.0-alpha | No |

## Reporting a vulnerability

Do not open a public issue.

Use GitHub's private reporting: **Security → Report a vulnerability** in this repository.

Include:

- affected version or commit
- firewall backend (iptables or nftables) and OS
- steps to reproduce
- impact, for example "banned IP still reaches SMTP"

The maintainer works on this project in spare time. Expect a first answer within 14 days.
Fixes ship in a new release with a note in `CHANGELOG.md`.

## Scope

In scope, because this repository controls it:

- `docker-compose.yml`, including the socket proxy permissions
- `acquis.yaml` and the selection of hub parsers and scenarios
- `crowdsec.sh`, including `setup-bouncer` and the generated bouncer config
- instructions in `INSTALL.md` that weaken the host, such as open ports or missing firewall chains
- bans that do not block traffic to Mailcow services

Out of scope, please report upstream:

- CrowdSec engine, bouncers or hub items: [crowdsecurity/crowdsec](https://github.com/crowdsecurity/crowdsec/security)
- Mailcow: [mailcow/mailcow-dockerized](https://github.com/mailcow/mailcow-dockerized/security)
- Socket proxy image: [linuxserver/docker-socket-proxy](https://github.com/linuxserver/docker-socket-proxy)

## Hardening notes for operators

- Keep the CrowdSec LAPI (`:8082`) bound to localhost.
- Whitelist your own admin networks before the first start, so you do not lock yourself out.
- Run `./crowdsec.sh health` after every upgrade. It checks LAPI, CAPI, bouncer and the `DOCKER-USER` chain.
