#!/usr/bin/env bash
# Enforcement test: a ban decision in the CrowdSec container must end up as a firewall rule that
# covers forwarded (Docker-published) traffic. Runs the real stack and the nftables bouncer.
# CI or a throwaway VM only: it installs/changes firewall rules and replaces the bouncer config.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."
PROJECT="mailcow_crowdsec_enforcement"
COMPOSE=(docker compose -p "$PROJECT")
IP=198.51.100.77

for name in crowdsec-mailcow crowdsec-socket-proxy; do
  if docker inspect "$name" >/dev/null 2>&1; then
    echo "FAIL: container '$name' already exists. Run this test only on a machine without Mailcow/CrowdSec (CI or a throwaway VM)."
    exit 1
  fi
done
if [[ $EUID -ne 0 ]]; then echo "FAIL: run as root"; exit 1; fi
if [[ ! -f /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml ]]; then
  echo "FAIL: nftables bouncer is not installed (apt install crowdsec-firewall-bouncer-nftables)"
  exit 1
fi

# shellcheck disable=SC2317  # invoked via trap
cleanup() { "${COMPOSE[@]}" down -v >/dev/null 2>&1 || true; }
trap cleanup EXIT

[[ -f /var/log/auth.log ]] || touch /var/log/auth.log
"${COMPOSE[@]}" up -d --wait --wait-timeout 180

./crowdsec.sh setup-bouncer
docker exec crowdsec-mailcow cscli decisions add --ip "$IP" --duration 10m --reason enforcement-test

ok=0
for _ in $(seq 1 30); do
  sleep 2
  if nft list ruleset 2>/dev/null | grep -q "$IP"; then ok=1; break; fi
done
if [[ $ok -ne 1 ]]; then
  echo "FAIL: $IP never appeared in the nftables ruleset"
  systemctl status crowdsec-firewall-bouncer --no-pager -l | tail -20 || true
  exit 1
fi

# The Docker-published Mailcow ports pass the forward hook, so the drop must be reachable from there.
ruleset=$(nft list ruleset)
if ! grep -qE 'hook forward' <<<"$(awk '/table ip crowdsec /,/^}/' <<<"$ruleset")"; then
  echo "FAIL: no forward hook in table ip crowdsec: bans would not block Docker-published ports"
  echo "$ruleset" | head -60
  exit 1
fi

# Removing the decision must remove the rule again
docker exec crowdsec-mailcow cscli decisions delete --ip "$IP" >/dev/null
for _ in $(seq 1 30); do
  sleep 2
  nft list ruleset 2>/dev/null | grep -q "$IP" || { echo "PASS: ban enforced on input and forward, lifted again"; exit 0; }
done
echo "FAIL: $IP still in the ruleset after the decision was deleted"
exit 1
