# Contributing

This project runs CrowdSec next to an unmodified Mailcow installation. Every change must keep three goals intact:

1. **Zero changes to Mailcow.** No edits to `mailcow.conf`, Mailcow's `docker-compose.yml` or its containers.
2. **Least privilege.** CrowdSec reads Docker logs only through the read-only socket proxy. Never mount `/var/run/docker.sock` into CrowdSec.
3. **Bans must block mail traffic.** Firewall changes must cover the `DOCKER-USER` chain, not only `INPUT`.

## Before you open an issue

- Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
- Run `./crowdsec.sh health` and add its output to the issue.
- Remove real IP addresses, domains and mail addresses from logs.

Security problems go through [SECURITY.md](SECURITY.md), not public issues.

## Development setup

You need Docker with Compose v2, `shellcheck` and root access for the integration test.

```bash
git clone https://github.com/PhilGabriel/mailcow_crowdsec.git
cd mailcow_crowdsec
cp .env.example .env
sudo touch /var/log/auth.log
```

Do not run the integration test on a production Mailcow host. It uses the same container names.

## Checks

CI runs the same three checks on every pull request:

```bash
shellcheck crowdsec.sh tests/run.sh
docker compose config -q
sudo ./tests/run.sh
```

## Adding a log source or parser

1. Add the source to `acquis.yaml`.
2. Add a sample log to `tests/logs/`. Use IPs from RFC 5737 (`198.51.100.0/24`), because the default whitelist drops private ranges.
3. Register the container and the expected IP in `tests/run.sh`.
4. Add a row to `tests/logs/README.md`.

## Pull requests

- Keep one topic per pull request.
- Write docs and commit messages in English.
- Update `CHANGELOG.md` under the next version. Use the sections Fixed, Security, Added, Removed and Changed.
- Update `README.md`, `INSTALL.md`, `TROUBLESHOOTING.md` or the pages in `wiki/` when behaviour changes.

The GitHub wiki is generated from `wiki/` on every merge to `main`. Edits made directly in the wiki web editor are overwritten.
- Describe upgrade steps if existing installations need manual action.

By contributing you agree that your work is licensed under the [MIT License](LICENSE).
