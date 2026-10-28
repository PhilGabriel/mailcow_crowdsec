#!/usr/bin/env bash
# Upgrade test: start an older release, create data, then run the current docker-compose.yml on the
# same volumes. Checks that bans and config survive and that the container (including cap_drop) can still
# write to its volumes, update the hub and talk to its LAPI.
# CI or a throwaway VM only: it creates containers named like the production ones.
# Usage: tests/upgrade.sh [old-git-ref]   (default: v0.2.1-alpha)
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."
OLD_REF=${1:-v0.2.1-alpha}
PROJECT="mailcow_crowdsec_upgrade"
IP=198.51.100.99

for name in crowdsec-mailcow crowdsec-socket-proxy; do
  if docker inspect "$name" >/dev/null 2>&1; then
    echo "FAIL: container '$name' already exists. Run this test only on a machine without Mailcow/CrowdSec (CI or a throwaway VM)."
    exit 1
  fi
done
[[ -f /var/log/auth.log ]] || touch /var/log/auth.log

old=$(mktemp -d)
cur=$PWD
# shellcheck disable=SC2317  # invoked via trap
cleanup() {
  (cd "$old" && docker compose -p "$PROJECT" down -v >/dev/null 2>&1) || true
  (cd "$cur" && docker compose -p "$PROJECT" down -v >/dev/null 2>&1) || true
  rm -rf "$old"
}
trap cleanup EXIT

git archive "$OLD_REF" | tar -x -C "$old"
echo "== old stack: $OLD_REF"
(cd "$old" && docker compose -p "$PROJECT" up -d --wait --wait-timeout 180)
docker exec crowdsec-mailcow cscli decisions add --ip "$IP" --duration 1h --reason upgrade-test >/dev/null
docker exec crowdsec-mailcow sh -c 'echo kept > /etc/crowdsec/upgrade-marker; echo kept > /var/lib/crowdsec/data/upgrade-marker'
# a file owned by another uid, as an older or hand-edited setup may leave behind
docker exec crowdsec-mailcow sh -c 'echo x > /etc/crowdsec/other-uid && chown 1000:1000 /etc/crowdsec/other-uid && chmod 600 /etc/crowdsec/other-uid'
(cd "$old" && docker compose -p "$PROJECT" down)

echo "== current stack on the same volumes"
docker compose -p "$PROJECT" up -d --wait --wait-timeout 180

fail=0
check() { # description, command...
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then echo "ok   $d"; else echo "FAIL $d"; fail=1; fi
}
check "ban survived the upgrade" bash -c "docker exec crowdsec-mailcow cscli decisions list -o raw | grep -q $IP"
check "config volume content kept" docker exec crowdsec-mailcow grep -q kept /etc/crowdsec/upgrade-marker
check "data volume content kept" docker exec crowdsec-mailcow grep -q kept /var/lib/crowdsec/data/upgrade-marker
check "write to config volume" docker exec crowdsec-mailcow sh -c 'echo ok > /etc/crowdsec/write-test'
check "write to data volume" docker exec crowdsec-mailcow sh -c 'echo ok > /var/lib/crowdsec/data/write-test'
check "new ban after upgrade" docker exec crowdsec-mailcow cscli decisions add --ip 198.51.100.98 --duration 5m
check "hub update" docker exec crowdsec-mailcow cscli hub update
check "hub upgrade" docker exec crowdsec-mailcow cscli hub upgrade
check "LAPI status" docker exec crowdsec-mailcow cscli lapi status
check "root can rewrite a file owned by another uid" docker exec crowdsec-mailcow sh -c 'echo y > /etc/crowdsec/other-uid'

if [[ $fail -ne 0 ]]; then
  docker logs crowdsec-mailcow 2>&1 | tail -30
  echo "FAIL: upgrade from $OLD_REF"
  exit 1
fi
echo "PASS: upgrade from $OLD_REF"
