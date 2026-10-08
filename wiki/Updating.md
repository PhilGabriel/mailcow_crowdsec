# Updating

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

## Update this project

```bash
cd mailcow_crowdsec
git pull
docker compose pull
docker compose up -d
sudo ./crowdsec.sh health
```

`docker-compose.yml` pins both images: `crowdsecurity/crowdsec:v1.8.1` and `lscr.io/linuxserver/socket-proxy:3.4.6`. New versions arrive through `git pull`. Read the [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md) before you update.

## Upgrade from 0.1.0-alpha

1. `git pull && docker compose pull && docker compose up -d`
2. `sudo ./crowdsec.sh setup-bouncer` (new key, `DOCKER-USER` chain, restart)
3. `./crowdsec.sh health`
4. Optional: `docker network rm mailcow_crowdsec_crowdsec-net` removes the old, unused network.

If you changed `acquis.yaml` locally, compare it with the new version. Postfix and Dovecot now use `type: syslog`, and every Docker source needs `docker_host: tcp://socket-proxy:2375`.

## Update hub items

```bash
./crowdsec.sh update
docker compose restart crowdsec
```

## Update the bouncer

```bash
apt update
apt upgrade crowdsec-firewall-bouncer-iptables   # or -nftables
systemctl restart crowdsec-firewall-bouncer
```

## Check versions

```bash
docker exec crowdsec-mailcow cscli version
docker exec crowdsec-mailcow cscli hub list
dpkg -l | grep crowdsec-firewall-bouncer
```
