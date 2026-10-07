#!/usr/bin/env bash
# Integration test: real CrowdSec + socket proxy, dummy Mailcow containers.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."
PROJECT="mailcow_crowdsec_test"
COMPOSE=(docker compose -p "$PROJECT")
# container name -> log file
declare -A DUMMIES=(
  [mailcowdockerized-postfix-mailcow-1]=postfix.log
  [mailcowdockerized-dovecot-mailcow-1]=dovecot.log
  [mailcowdockerized-nginx-mailcow-1]=nginx.log
  [mailcowdockerized-netfilter-mailcow-1]=netfilter.log
)
EXPECTED=(198.51.100.10 198.51.100.20 198.51.100.30 198.51.100.40)

cleanup() {
  docker rm -f "${!DUMMIES[@]}" >/dev/null 2>&1 || true
  "${COMPOSE[@]}" down -v >/dev/null 2>&1 || true
}
trap cleanup EXIT

if [[ ! -f /var/log/auth.log ]]; then
  echo "FAIL: /var/log/auth.log missing (create it with: touch /var/log/auth.log)"
  exit 1
fi

"${COMPOSE[@]}" up -d --wait --wait-timeout 180

# Dummies start after CrowdSec, so it must pick them up via Docker events
for name in "${!DUMMIES[@]}"; do
  docker run -d --name "$name" -v "$PWD/tests/logs/${DUMMIES[$name]}:/log:ro" \
    alpine:3 sh -c 'sleep 5; cat /log; sleep 3600' >/dev/null
done

missing=("${EXPECTED[@]}")
for _ in $(seq 1 30); do
  sleep 2
  alerts=$(docker exec crowdsec-mailcow cscli alerts list -o raw)
  missing=()
  for ip in "${EXPECTED[@]}"; do
    grep -q "$ip" <<<"$alerts" || missing+=("$ip")
  done
  [[ ${#missing[@]} -eq 0 ]] && break
done

docker exec crowdsec-mailcow cscli alerts list
docker exec crowdsec-mailcow cscli metrics show acquisition parsers

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "FAIL: no alert for ${missing[*]}"
  docker logs crowdsec-mailcow 2>&1 | tail -40
  exit 1
fi
echo "PASS: alerts for ${EXPECTED[*]}"
