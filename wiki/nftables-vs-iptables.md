# nftables vs iptables

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

The bouncer exists as two packages. Install the one that matches your firewall backend.

## Check your system

```bash
iptables --version
```

| Output contains | Backend | Package |
|----------------|---------|---------|
| `(nf_tables)` | nftables | `crowdsec-firewall-bouncer-nftables` |
| `(legacy)` | iptables | `crowdsec-firewall-bouncer-iptables` |

Both packages come from the CrowdSec apt repository (`curl -s https://install.crowdsec.net | sh`).

## Docker-published ports

Mailcow's ports are published by Docker, so mail traffic passes `FORWARD`, not `INPUT`.

| Package | Default hooks | Change needed |
|---------|---------------|---------------|
| iptables | `INPUT` | add `DOCKER-USER` to `iptables_chains` (`setup-bouncer` does it) |
| nftables | `input`, `forward` | none |

## Switching packages

```bash
systemctl stop crowdsec-firewall-bouncer
apt remove crowdsec-firewall-bouncer-iptables
apt install crowdsec-firewall-bouncer-nftables
sudo ./crowdsec.sh setup-bouncer
systemctl enable crowdsec-firewall-bouncer
```

## Verify

```bash
sudo ./crowdsec.sh health

# iptables
iptables -S INPUT | grep -i crowdsec
iptables -S DOCKER-USER | grep -i crowdsec

# nftables
nft list tables | grep crowdsec
```

Do not install both packages. netfilter-mailcow uses its own `MAILCOW` chain and does not conflict with either.
