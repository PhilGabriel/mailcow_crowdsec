#!/usr/bin/env bash
# CrowdSec for Mailcow — Helper Script
# Usage: ./crowdsec.sh <command>

set -euo pipefail

CONTAINER="crowdsec-mailcow"
BOUNCER_CONTAINER="crowdsec-firewall-bouncer"

usage() {
  cat <<EOF
CrowdSec for Mailcow — Helper Script

Usage: ./crowdsec.sh <command>

Commands:
  status      Show full status overview (containers, bans, metrics)
  bans        List all active bans
  alerts      Show recent alerts
  metrics     Show log processing metrics
  unban       Remove a ban by IP:     ./crowdsec.sh unban 1.2.3.4
  whitelist   Show currently whitelisted IPs
  update      Update CrowdSec hub (parsers, scenarios, collections)
  logs        Follow CrowdSec logs in real time
  health      Check CAPI and bouncer connectivity
EOF
}

require_container() {
  if ! docker inspect "$CONTAINER" &>/dev/null; then
    echo "Error: Container '$CONTAINER' is not running."
    exit 1
  fi
}

cmd_status() {
  require_container
  echo "=== Container Status ==="
  docker compose ps 2>/dev/null || docker ps --filter "name=crowdsec" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

  echo ""
  echo "=== Active Bans ==="
  docker exec "$CONTAINER" cscli decisions list -a 2>/dev/null || echo "(none)"

  echo ""
  echo "=== Bouncer Status ==="
  docker exec "$CONTAINER" cscli bouncers list 2>/dev/null

  echo ""
  echo "=== Log Processing ==="
  docker exec "$CONTAINER" cscli metrics show acquisition 2>/dev/null
}

cmd_bans() {
  require_container
  docker exec "$CONTAINER" cscli decisions list -a
}

cmd_alerts() {
  require_container
  docker exec "$CONTAINER" cscli alerts list --limit 20
}

cmd_metrics() {
  require_container
  docker exec "$CONTAINER" cscli metrics
}

cmd_unban() {
  require_container
  local ip="${1:-}"
  if [[ -z "$ip" ]]; then
    echo "Usage: ./crowdsec.sh unban <IP>"
    exit 1
  fi
  docker exec "$CONTAINER" cscli decisions delete --ip "$ip"
  echo "Ban removed for $ip"
}

cmd_whitelist() {
  require_container
  echo "=== Whitelist files ==="
  docker exec "$CONTAINER" find /etc/crowdsec/parsers -name "*whitelist*" -exec echo {} \; -exec cat {} \; 2>/dev/null || echo "(no custom whitelists found)"
}

cmd_update() {
  require_container
  echo "Updating CrowdSec hub..."
  docker exec "$CONTAINER" cscli hub update
  echo ""
  echo "Upgrading installed components..."
  docker exec "$CONTAINER" cscli hub upgrade
  echo ""
  echo "Done. Consider restarting: docker compose restart crowdsec"
}

cmd_logs() {
  docker logs -f "$CONTAINER" 2>&1
}

cmd_health() {
  require_container
  echo "=== CAPI Status ==="
  docker exec "$CONTAINER" cscli capi status 2>/dev/null

  echo ""
  echo "=== Bouncer Status ==="
  docker exec "$CONTAINER" cscli bouncers list 2>/dev/null

  echo ""
  echo "=== LAPI Healthcheck ==="
  if curl -sf http://127.0.0.1:8082/v1/heartbeat >/dev/null 2>&1; then
    echo "LAPI is healthy ✓"
  else
    echo "LAPI is NOT reachable ✗"
  fi
}

case "${1:-}" in
  status)    cmd_status ;;
  bans)      cmd_bans ;;
  alerts)    cmd_alerts ;;
  metrics)   cmd_metrics ;;
  unban)     cmd_unban "${2:-}" ;;
  whitelist) cmd_whitelist ;;
  update)    cmd_update ;;
  logs)      cmd_logs ;;
  health)    cmd_health ;;
  *)         usage ;;
esac
