#!/usr/bin/env bash
# Log rotation test: SSH detection must survive a logrotate-style rotation of /var/log/auth.log
# (rename + new file). A single-file bind mount keeps reading the old inode and fails here.
# CI or a throwaway VM only: it creates containers named like the production ones and
# writes to and rotates the host's /var/log/auth.log. Needs root.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."
PROJECT="mailcow_crowdsec_rotation"
COMPOSE=(docker compose -p "$PROJECT")
LOG=/var/log/auth.log
ROTATED=$LOG.rotation-test
BEFORE=198.51.100.50
AFTER=198.51.100.60

# shellcheck disable=SC2317,SC2329  # invoked via trap
cleanup() {
  "${COMPOSE[@]}" down -v >/dev/null 2>&1 || true
  # put the original file back in place
  [[ -f $ROTATED ]] && mv -f "$ROTATED" "$LOG"
  return 0
}
trap cleanup EXIT

for name in crowdsec-mailcow crowdsec-socket-proxy; do
  if docker inspect "$name" >/dev/null 2>&1; then
    echo "FAIL: container '$name' already exists. Run this test only on a machine without Mailcow/CrowdSec (CI or a throwaway VM)."
    exit 1
  fi
done
if [[ -e $ROTATED ]]; then
  echo "FAIL: $ROTATED already exists (left over from an aborted run?)"
  exit 1
fi
[[ -f $LOG ]] || touch "$LOG"

attack() { # ip
  local i
  for i in $(seq 1 10); do
    echo "$(LC_ALL=C date '+%b %e %H:%M:%S') testhost sshd[$((4000 + i))]: Failed password for invalid user admin from $1 port $((50000 + i)) ssh2" >>"$LOG"
  done
}

wait_alert() { # ip
  local _
  for _ in $(seq 1 30); do
    docker exec crowdsec-mailcow cscli alerts list -o raw | grep -q "$1" && return 0
    sleep 2
  done
  echo "FAIL: no alert for $1"
  docker exec crowdsec-mailcow cscli metrics show acquisition || true
  docker logs crowdsec-mailcow 2>&1 | tail -40
  exit 1
}

"${COMPOSE[@]}" up -d --wait --wait-timeout 180

attack "$BEFORE"
wait_alert "$BEFORE"
echo "ok   alert before rotation ($BEFORE)"

# what logrotate does on Debian/Ubuntu (no copytruncate)
mv "$LOG" "$ROTATED"
touch "$LOG"
sleep 5 # let CrowdSec notice the new file before writing to it
attack "$AFTER"
wait_alert "$AFTER"
echo "ok   alert after rotation ($AFTER)"

echo "PASS: SSH detection survives log rotation"
