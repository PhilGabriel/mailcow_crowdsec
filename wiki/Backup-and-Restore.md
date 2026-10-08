# Backup and Restore

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

## What to back up

| Data | Location | Contains |
|------|----------|----------|
| Database | volume `mailcow_crowdsec_crowdsec-db` | decisions, alerts, bouncer registrations |
| Config | volume `mailcow_crowdsec_crowdsec-config` | whitelists, hub items, local config |
| Bouncer config | `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml` | API URL, API key, chains |
| `acquis.yaml`, `.env` | repository directory | log sources, timezone, enrollment |

The volume prefix matches the directory name of your clone. Check with `docker volume ls | grep crowdsec`.

## Backup

The CrowdSec image contains no `sqlite3`. Stop the container for a consistent copy:

```bash
docker compose stop crowdsec
for v in crowdsec-db crowdsec-config; do
  docker run --rm -v mailcow_crowdsec_$v:/data:ro -v "$PWD":/backup alpine \
    tar czf /backup/$v.tar.gz -C /data .
done
docker compose start crowdsec
cp /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml ./bouncer-config-backup.yaml
```

## Restore

```bash
docker compose stop crowdsec
for v in crowdsec-db crowdsec-config; do
  docker run --rm -v mailcow_crowdsec_$v:/data -v "$PWD":/backup alpine \
    sh -c "rm -rf /data/* && tar xzf /backup/$v.tar.gz -C /data"
done
docker compose start crowdsec
```

If you restored the database, the old bouncer key is valid again. Put back the matching bouncer config, or run `sudo ./crowdsec.sh setup-bouncer` for a new key.

## Warnings

- `docker compose down -v` deletes both volumes.
- A lost bouncer key cannot be recovered. `setup-bouncer` creates a new one.
