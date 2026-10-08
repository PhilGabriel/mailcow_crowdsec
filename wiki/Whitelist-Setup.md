# Whitelist Setup

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

A whitelist stops CrowdSec from banning trusted IPs. Set it up **before** the first ban hits you. Candidates:

- your own public IP (SSH, admin access)
- monitoring systems
- the reverse proxy in front of Mailcow, if any
- partner mail servers

## Create a whitelist

```bash
docker exec crowdsec-mailcow sh -c 'cat > /etc/crowdsec/parsers/s02-enrich/my-whitelist.yaml << EOT
name: local/my-whitelist
description: "Whitelist trusted IPs"
whitelist:
  reason: "trusted network"
  ip:
    - "YOUR_PUBLIC_IP"
    - "MONITORING_IP"
  cidr:
    - "10.0.0.0/8"
    - "172.16.0.0/12"
    - "192.168.0.0/16"
EOT'
docker compose restart crowdsec
```

## Verify

```bash
./crowdsec.sh whitelist
docker exec crowdsec-mailcow cscli metrics | grep -i whitelist
```

## Notes

- The file lives in the `crowdsec-config` volume. `docker compose down -v` deletes it, see [[Backup and Restore]].
- The hub parser `crowdsecurity/whitelists` already skips private ranges. The explicit CIDR entries above do no harm.
- The whitelist does not affect netfilter-mailcow. Configure its own whitelist in the Mailcow admin UI under "Fail2ban parameters".
