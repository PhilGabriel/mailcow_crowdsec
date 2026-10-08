# Helper Script

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

`crowdsec.sh` wraps common CrowdSec operations. It works from any directory and stops with an error if `crowdsec-mailcow` is not running.

## Commands

| Command | Description |
|---------|-------------|
| `status` | Container, bouncer service, bouncer registration, local bans, acquisition metrics |
| `bans` | Local bans only |
| `bans --all` | Local bans plus the community blocklist |
| `alerts` | Last 20 alerts |
| `metrics` | Full `cscli metrics` output |
| `unban <IP>` | Remove the bans for one IP |
| `whitelist` | Show whitelist files and their contents |
| `update` | `cscli hub update` and `hub upgrade` |
| `logs` | Follow the CrowdSec log (Ctrl+C stops) |
| `health` | LAPI, CAPI, bouncer registration, bouncer service, firewall rules incl. `DOCKER-USER` |
| `setup-bouncer` | Register the host bouncer, write `api_url`, `api_key` and `DOCKER-USER`, restart it |

## Examples

```bash
sudo ./crowdsec.sh health          # everything working?
./crowdsec.sh unban 203.0.113.42   # someone locked out
./crowdsec.sh bans --all | head    # community blocklist loaded?
sudo ./crowdsec.sh setup-bouncer   # new key, e.g. after reinstalling the bouncer
```

## Notes

- `setup-bouncer` needs root and an installed bouncer package. Each run replaces the API key, because CrowdSec cannot show an existing key again. The old config stays as `crowdsec-firewall-bouncer.yaml.bak`.
- `health` reads iptables and nftables. Without root it reports missing rules even if they exist.
- The script needs `docker`, `systemctl` and `curl`.
