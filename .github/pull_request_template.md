## What changes

<!-- One topic per pull request. Link the issue if one exists. -->

## Why

## Checks

- [ ] `shellcheck crowdsec.sh tests/run.sh` passes
- [ ] `docker compose config -q` passes
- [ ] `sudo ./tests/run.sh` passes, or CI ran it
- [ ] New log sources have a sample in `tests/logs/` and an expected IP in `tests/run.sh`
- [ ] `CHANGELOG.md` updated
- [ ] Docs updated if behaviour changed

## Project goals

- [ ] No changes to Mailcow itself
- [ ] CrowdSec still has no direct Docker socket access
- [ ] Bans still cover the `DOCKER-USER` chain

## Upgrade steps for existing installations

<!-- "None" if nothing to do. -->
