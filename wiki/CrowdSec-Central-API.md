# CrowdSec Central API

> ⚠️ **ALPHA SOFTWARE** — This project is experimental and not yet stable for general use. Test in a non-production environment first.
>
> Wiki state: **v0.2.0-alpha** · CrowdSec v1.8.1 · [Changelog](https://github.com/PhilGabriel/mailcow_crowdsec/blob/main/CHANGELOG.md)

Enrolling connects your instance to the web console at [app.crowdsec.net](https://app.crowdsec.net). It is optional: the community blocklist works without an account.

## What you get

- alert feed and ban history in the browser
- statistics on attack patterns
- remote management of the instance

## Setup

1. Register at [app.crowdsec.net](https://app.crowdsec.net).
2. Open **Security Engines → Add** and copy the enrollment key.
3. Add to `.env`:

   ```
   CROWDSEC_ENROLL_KEY=your_enrollment_key_here
   CROWDSEC_INSTANCE_NAME=my-mailcow-server
   ```

4. Uncomment these lines under `environment` in `docker-compose.yml`:

   ```yaml
   ENROLL_KEY: "${CROWDSEC_ENROLL_KEY}"
   ENROLL_INSTANCE_NAME: "${CROWDSEC_INSTANCE_NAME}"
   ```

5. Recreate the container, so it reads the new environment:

   ```bash
   docker compose up -d
   ```

6. Accept the enrollment in the console.

## Verify

```bash
docker exec crowdsec-mailcow cscli capi status
```

`git pull` may conflict with your local change in `docker-compose.yml`. Keep your two lines when you merge.
