# Uninstall

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

Mailcow's `netfilter-mailcow` keeps running throughout. Mailcow needs no change.

## 1. Remove the firewall bouncer

```bash
systemctl disable --now crowdsec-firewall-bouncer
apt remove crowdsec-firewall-bouncer-iptables   # or -nftables
```

## 2. Remove CrowdSec and the socket proxy

```bash
cd mailcow_crowdsec
docker compose down
```

## 3. Remove the volumes

This deletes all CrowdSec data, including whitelists:

```bash
docker volume rm mailcow_crowdsec_crowdsec-db mailcow_crowdsec_crowdsec-config
```

## 4. Verify

```bash
iptables -S | grep -i crowdsec
nft list tables | grep crowdsec
docker ps -a | grep crowdsec
# → all three return nothing
```

Optional: `apt remove rsyslog` if you installed it only for this project, and remove the CrowdSec apt repository from `/etc/apt/sources.list.d/`.
