#!/usr/bin/env bash
# CrowdSec for Mailcow — Helper Script
# Usage: ./crowdsec.sh <command>

set -euo pipefail

CONTAINER="crowdsec-mailcow"
BOUNCER_NAME="firewall-bouncer"
BOUNCER_CONFIG="/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml"

# docker compose needs the project directory, wherever the script is called from
cd "$(dirname "$(readlink -f "$0")")"

usage() {
  cat <<EOF
CrowdSec for Mailcow — Helper Script

Usage: ./crowdsec.sh <command>

Commands:
  status      Show full status overview (container, bouncer, bans, metrics)
  bans        List local bans (add --all to include the community blocklist)
  alerts      Show recent alerts
  metrics     Show log processing metrics
  unban IP    Remove a ban by IP
  whitelist   Show currently whitelisted IPs
  update      Update CrowdSec hub (parsers, scenarios, collections)
  logs        Follow CrowdSec logs in real time
  health      Check LAPI, CAPI, and bouncer connectivity
  setup-bouncer  Register the host firewall bouncer and write its config (root)
EOF
}

require_container() {
  if [[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]]; then
    echo "Error: Container '$CONTAINER' is not running."
    exit 1
  fi
}

cmd_status() {
  require_container
  echo "=== CrowdSec Container ==="
  docker compose ps 2>/dev/null || docker ps --filter "name=$CONTAINER" --format "table {{.Names}}\t{{.Status}}"

  echo ""
  echo "=== Firewall Bouncer (host) ==="
  if systemctl is-active crowdsec-firewall-bouncer &>/dev/null; then
    echo "● crowdsec-firewall-bouncer: active (running)"
  else
    echo "○ crowdsec-firewall-bouncer: inactive or not installed"
  fi

  echo ""
  echo "=== Bouncer API Connection ==="
  docker exec "$CONTAINER" cscli bouncers list 2>/dev/null

  echo ""
  echo "=== Active Bans (local) ==="
  docker exec "$CONTAINER" cscli decisions list 2>/dev/null || echo "(none)"

  echo ""
  echo "=== Log Processing ==="
  docker exec "$CONTAINER" cscli metrics show acquisition 2>/dev/null
}

cmd_bans() {
  require_container
  if [[ "${1:-}" == "--all" ]]; then
    docker exec "$CONTAINER" cscli decisions list -a
  else
    docker exec "$CONTAINER" cscli decisions list
  fi
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
  require_container
  docker logs -f "$CONTAINER" 2>&1
}

cmd_health() {
  require_container

  echo "=== LAPI Healthcheck ==="
  if curl -sf http://127.0.0.1:8082/v1/heartbeat >/dev/null 2>&1; then
    echo "✓ LAPI is healthy (port 8082)"
  else
    echo "✗ LAPI is NOT reachable on port 8082"
  fi

  echo ""
  echo "=== CAPI Status ==="
  docker exec "$CONTAINER" cscli capi status 2>/dev/null || echo "✗ CAPI not connected"

  echo ""
  echo "=== Bouncer Connection ==="
  docker exec "$CONTAINER" cscli bouncers list 2>/dev/null

  echo ""
  echo "=== Firewall Bouncer Service ==="
  if systemctl is-active crowdsec-firewall-bouncer &>/dev/null; then
    echo "✓ crowdsec-firewall-bouncer is running"
    systemctl status crowdsec-firewall-bouncer --no-pager -l 2>/dev/null | grep -E "Active:|Main PID:" || true
  else
    echo "✗ crowdsec-firewall-bouncer is NOT running"
    echo "  Install: apt install crowdsec-firewall-bouncer-iptables"
  fi

  echo ""
  echo "=== Firewall Rules ==="
  if nft list tables 2>/dev/null | grep -q crowdsec; then
    echo "✓ CrowdSec nftables tables are active"
  else
    local chain
    for chain in INPUT DOCKER-USER; do
      if iptables -S "$chain" 2>/dev/null | grep -q crowdsec; then
        echo "✓ CrowdSec rule present in iptables chain $chain"
      else
        echo "✗ No CrowdSec rule in iptables chain $chain"
      fi
    done
    echo "  Mailcow ports are published by Docker: without DOCKER-USER, bans do not block mail traffic."
  fi
}

cmd_setup_bouncer() {
  require_container
  if [[ $EUID -ne 0 ]]; then
    echo "Error: run as root (writes $BOUNCER_CONFIG and restarts the bouncer)."
    exit 1
  fi
  if [[ ! -f "$BOUNCER_CONFIG" ]]; then
    echo "Error: $BOUNCER_CONFIG not found. Install the bouncer package first (see INSTALL.md)."
    exit 1
  fi

  # A key cannot be read back, so an existing registration is replaced
  if docker exec "$CONTAINER" cscli bouncers list -o raw | grep -q "^$BOUNCER_NAME,"; then
    echo "Replacing existing bouncer registration '$BOUNCER_NAME'"
    docker exec "$CONTAINER" cscli bouncers delete "$BOUNCER_NAME" &>/dev/null
  fi
  local key
  key=$(docker exec "$CONTAINER" cscli bouncers add "$BOUNCER_NAME" -o raw)

  cp "$BOUNCER_CONFIG" "$BOUNCER_CONFIG.bak"
  sed -i -e "s|^api_url:.*|api_url: http://127.0.0.1:8082/|" \
         -e "s|^api_key:.*|api_key: $key|" "$BOUNCER_CONFIG"

  # Docker-published Mailcow ports bypass INPUT (nftables mode hooks forward by default)
  if grep -qE "^mode: *(iptables|ipset)" "$BOUNCER_CONFIG" && ! grep -qE "^ *- *DOCKER-USER" "$BOUNCER_CONFIG"; then
    sed -i "/^iptables_chains:/a\\  - DOCKER-USER" "$BOUNCER_CONFIG"
    echo "Added DOCKER-USER to iptables_chains"
  fi
  echo "Updated $BOUNCER_CONFIG (backup: $BOUNCER_CONFIG.bak)"

  systemctl restart crowdsec-firewall-bouncer
  sleep 3
  docker exec "$CONTAINER" cscli bouncers list
}

case "${1:-}" in
  status)    cmd_status ;;
  bans)      cmd_bans "${2:-}" ;;
  alerts)    cmd_alerts ;;
  metrics)   cmd_metrics ;;
  unban)     cmd_unban "${2:-}" ;;
  whitelist) cmd_whitelist ;;
  update)    cmd_update ;;
  logs)      cmd_logs ;;
  health)    cmd_health ;;
  setup-bouncer) cmd_setup_bouncer ;;
  *)         usage ;;
esac
