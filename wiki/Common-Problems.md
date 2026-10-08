# Common Problems

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

The full guide is [TROUBLESHOOTING.md](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/TROUBLESHOOTING.md). Start with:

```bash
sudo ./crowdsec.sh health
```

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Bans block SSH, not SMTP/IMAP/webmail | `DOCKER-USER` missing in iptables mode | `sudo ./crowdsec.sh setup-bouncer`, see [[nftables vs iptables]] |
| `bind source path does not exist: /var/log/auth.log` | No rsyslog | [Missing log files](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/TROUBLESHOOTING.md#missing-log-files) |
| No `docker:` sources in acquisition metrics | Socket proxy denies requests or crashes | [No log lines read at all](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/TROUBLESHOOTING.md#no-log-lines-read-at-all) |
| Socket proxy restarts, `[:::2375]` in its log | Host has IPv6 disabled | `DISABLE_IPV6: 1` must stay in `docker-compose.yml` |
| Sources read, but 0 lines for one service | Container names differ | [[Acquis Configuration]] |
| Postfix lines unparsed | Old `acquis.yaml` with `type: postfix` | Use `type: syslog`, see [[Updating]] |
| Bouncer `unauthorized` / `403` | Wrong or old API key | `sudo ./crowdsec.sh setup-bouncer` |
| Bouncer `connection refused` | CrowdSec not running or not healthy | `docker compose ps` |
| No bans | No attack detected yet | `./crowdsec.sh alerts` |
| Reverse proxy IP banned | Proxy not whitelisted | [Reverse proxy](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/TROUBLESHOOTING.md#mailcow-behind-a-reverse-proxy) |
| Locked out | Own IP banned | [[Lockout Recovery]] |
| High CPU | Attack or log catch-up | `./crowdsec.sh alerts` |

Still stuck? Open a [bug report](https://github.com/PhilGabriel/mailcow_crowdsec/issues/new/choose) with the output of `./crowdsec.sh health`. Remove real IPs and domains first.
