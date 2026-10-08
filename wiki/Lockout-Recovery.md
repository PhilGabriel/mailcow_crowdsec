# Lockout Recovery

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

You banned your own IP and cannot reach the server.

## With console access

Most hosting providers offer a KVM console or a rescue system.

### Option 1: remove the ban

```bash
docker exec crowdsec-mailcow cscli decisions delete --ip YOUR_IP
```

### Option 2: stop the bouncer first

```bash
systemctl stop crowdsec-firewall-bouncer
docker exec crowdsec-mailcow cscli decisions delete --ip YOUR_IP
systemctl start crowdsec-firewall-bouncer
```

## Banned by netfilter-mailcow instead?

If `cscli decisions list` does not show your IP, netfilter-mailcow may have banned it. Remove that ban in the Mailcow admin UI under "Fail2ban parameters", or check its chain:

```bash
iptables -S MAILCOW | grep YOUR_IP
```

A netfilter ban also becomes a CrowdSec decision through `Guezli/mailcow-f2b-feed`. Remove both.

## Without console access

Ask your hosting provider to run `systemctl stop crowdsec-firewall-bouncer` or to give you temporary console access.

## Prevention

Set up [[Whitelist Setup]] right after installation.
