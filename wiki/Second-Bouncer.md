# Second Bouncer

> ℹ️ **BETA** — Detection, ban enforcement (nftables and iptables) and the upgrade from the last release are covered by CI. Known gaps: see [Known limitations](https://github.com/PhilGabriel/mailcow_crowdsec#known-limitations). Test in a non-production environment first.
>
> Wiki state: **v0.4.0-beta** · CrowdSec v1.8.2 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

For hosts that **already run CrowdSec** (the `crowdsec` package) next to this stack.

## The problem

A firewall bouncer talks to exactly one LAPI. On such a host the existing bouncer talks to the host LAPI. This container detects attacks on Postfix, Dovecot and Nginx, but its bans (`postfix-spam`, `postscreen-rbl`, `dovecot-spam`, ...) stay inside the container's LAPI. Nobody turns them into firewall rules.

Plain `setup-bouncer` is no answer: it repoints the existing bouncer from the host LAPI to the container LAPI.

## The solution

```bash
sudo ./crowdsec.sh setup-bouncer --second
```

This starts a second instance of the same bouncer binary next to the first one. The first one is not touched (its config stays byte-identical, CI checks that).

| | First bouncer | Second bouncer |
|---|---|---|
| Service | `crowdsec-firewall-bouncer` | `crowdsec-firewall-bouncer-mailcow` |
| Config | `crowdsec-firewall-bouncer.yaml` | `crowdsec-firewall-bouncer-mailcow.yaml` |
| LAPI | host, `127.0.0.1:8080` | container, `127.0.0.1:8082` |
| nftables tables | `crowdsec`, `crowdsec6` | `crowdsec-mailcow`, `crowdsec6-mailcow` |
| Registered as | on the host LAPI | `firewall-bouncer-mailcow` in the container |
| Log | as configured | journal (`journalctl -u crowdsec-firewall-bouncer-mailcow`) |

The tables must differ: the nftables backend deletes tables it does not know on shutdown.

## What the command does

1. Registers `firewall-bouncer-mailcow` in the container. An existing registration is replaced (a key cannot be read back).
2. Derives the config from the first bouncer's config: `api_url` and `api_key`, own tables, chains and set names, `log_mode: stdout`, Prometheus off.
3. Adds `origins: [crowdsec, cscli]`. Only bans that were detected here or added by hand are enforced. The community blocklist is not loaded a second time, because the host instance already has it.
4. Checks the config with `crowdsec-firewall-bouncer -t`. It aborts if it is invalid.
5. Writes `/etc/systemd/system/crowdsec-firewall-bouncer-mailcow.service`, enables it and starts it.

Requirements: root, the nftables bouncer package, and an existing `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml` with `mode: nftables`. With the iptables bouncer a second instance is not supported.

Running it again replaces the key and the config (previous config: `.bak`).

## Verify

```bash
systemctl is-active crowdsec-firewall-bouncer crowdsec-firewall-bouncer-mailcow
docker exec crowdsec-mailcow cscli decisions list        # bans of the container
nft list table ip crowdsec-mailcow                       # the same IPs, input and forward hook
```

`./crowdsec.sh status` shows the second service as well.

## Lifting a ban

The IP is blocked by the container's decision, not by the host's:

```bash
./crowdsec.sh unban 203.0.113.42
```

The rule disappears within one update interval (10 s).

## Remove

```bash
systemctl disable --now crowdsec-firewall-bouncer-mailcow
rm /etc/systemd/system/crowdsec-firewall-bouncer-mailcow.service /etc/crowdsec/bouncers/crowdsec-firewall-bouncer-mailcow.yaml*
systemctl daemon-reload
docker exec crowdsec-mailcow cscli bouncers delete firewall-bouncer-mailcow
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `--second needs the nftables firewall bouncer` | The first bouncer is missing or uses iptables. Without an existing bouncer run plain `setup-bouncer`. |
| `generated config is invalid` | Run `crowdsec-firewall-bouncer -c /etc/crowdsec/bouncers/crowdsec-firewall-bouncer-mailcow.yaml -t` and read the error. |
| `unauthorized` / `403` in the journal | Run `sudo ./crowdsec.sh setup-bouncer --second` again (new key). |
| Container bans missing in `crowdsec-mailcow` | Check `systemctl status crowdsec-firewall-bouncer-mailcow` and that the container is healthy. The service restarts every 10 s until the LAPI answers. |
| A legitimate IP is blocked | `./crowdsec.sh unban <IP>`, then add it to the whitelist, see [[Whitelist Setup]]. |

See also [[Requirements]] (CrowdSec already installed on the host) and [[Helper Script]].
