# Integration test

`run.sh` starts the stack from `docker-compose.yml`, then starts dummy containers
with the Mailcow container names. Each dummy prints one file from `logs/` to stdout.
The test passes when CrowdSec raises an alert for every attacker IP.

| File | Format source | Expected alert for |
|---|---|---|
| `postfix.log` | CrowdSec hub test `postfix-logs` | 198.51.100.10 |
| `dovecot.log` | CrowdSec hub test `dovecot-logs` | 198.51.100.20 |
| `nginx.log` | Mailcow `log_format main` (`nginx.conf.j2`) | 198.51.100.30 |
| `netfilter.log` | Mailcow `netfilter/modules/Logger.py` | 198.51.100.40 |

IPs come from the documentation ranges (RFC 5737). Private ranges would be
dropped by the default `crowdsecurity/whitelists` parser.

```bash
sudo ./tests/run.sh
```

The script removes its containers and volumes afterwards. Do not run it on a
production Mailcow host: it uses the same container names.
