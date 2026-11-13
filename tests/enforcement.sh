#!/usr/bin/env bash
# Enforcement test: a ban decision in the CrowdSec container must end up as a firewall rule that
# covers forwarded (Docker-published) traffic. Runs the real stack and the nftables or iptables bouncer.
# Usage: tests/enforcement.sh [nftables|iptables|second]   (default: nftables)
# "second" = nftables bouncer for the container PLUS an existing first bouncer (setup-bouncer --second).
# CI or a throwaway VM only: it installs/changes firewall rules and replaces the bouncer config.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."
PROJECT="mailcow_crowdsec_enforcement"
COMPOSE=(docker compose -p "$PROJECT")
IP=198.51.100.77
MODE=${1:-nftables}
[[ $MODE == nftables || $MODE == iptables || $MODE == second ]] || { echo "usage: $0 [nftables|iptables|second]"; exit 1; }
# The second instance enforces through its own nftables tables
TABLE=crowdsec
SERVICE=crowdsec-firewall-bouncer
LISTENER=enforcement-listener NS=enforcement GW=198.51.100.1 PORT=18025
if [[ $MODE == second ]]; then MODE=nftables; TABLE=crowdsec-mailcow; SERVICE=crowdsec-firewall-bouncer-mailcow; SECOND=1; fi

for name in crowdsec-mailcow crowdsec-socket-proxy; do
  if docker inspect "$name" >/dev/null 2>&1; then
    echo "FAIL: container '$name' already exists. Run this test only on a machine without Mailcow/CrowdSec (CI or a throwaway VM)."
    exit 1
  fi
done
if [[ $EUID -ne 0 ]]; then echo "FAIL: run as root"; exit 1; fi
if [[ ! -f /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml ]]; then
  echo "FAIL: $MODE bouncer is not installed (apt install crowdsec-firewall-bouncer-$MODE)"
  exit 1
fi

# shellcheck disable=SC2317,SC2329  # invoked via trap
cleanup() {
  "${COMPOSE[@]}" down -v >/dev/null 2>&1 || true
  docker rm -f "$LISTENER" >/dev/null 2>&1 || true
  ip netns del "$NS" 2>/dev/null || true  # takes the veth pair with it
}
trap cleanup EXIT

# A client with the banned source address, routed to a Docker-published port: the same
# DNAT/forward path Mailcow's ports take. -v logs the peer address; without -e busybox nc exits after one client.
docker run -d --name "$LISTENER" -p "$PORT:$PORT" alpine:3 nc -lkv -p "$PORT" -e true >/dev/null
ip netns add "$NS"
ip link add enf-host type veth peer name enf-client netns "$NS"
ip addr add "$GW/24" dev enf-host
ip link set enf-host up
ip -n "$NS" addr add "$IP/24" dev enf-client
ip -n "$NS" link set enf-client up
connects() { ip netns exec "$NS" timeout 3 bash -c "exec 3<>/dev/tcp/$GW/$PORT" 2>/dev/null; }

[[ -f /var/log/auth.log ]] || touch /var/log/auth.log
"${COMPOSE[@]}" up -d --wait --wait-timeout 180

if [[ -n ${SECOND:-} ]]; then
  before=$(sha256sum /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml)
  ./crowdsec.sh setup-bouncer --second
  # The first bouncer's config must stay as it was
  [[ $before == "$(sha256sum /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml)" ]] || { echo "FAIL: --second changed the first bouncer's config"; exit 1; }
else
  ./crowdsec.sh setup-bouncer
fi

# Without a ban the connection must work, and arrive with the client's address (not via docker-proxy),
# otherwise the checks below prove nothing
if ! connects || ! sleep 1 || ! docker logs "$LISTENER" 2>&1 | grep -qF "$IP"; then
  echo "FAIL: test setup: $IP cannot reach the published port through the forward path before the ban"
  exit 1
fi
docker exec crowdsec-mailcow cscli decisions add --ip "$IP" --duration 10m --reason enforcement-test

# Is the banned IP currently known to the firewall?
banned() {
  if [[ $MODE == nftables ]]; then nft list ruleset 2>/dev/null | grep -q "$IP"; else ipset save 2>/dev/null | grep -q "$IP"; fi
}

ok=0
for _ in $(seq 1 30); do
  sleep 2
  if banned; then ok=1; break; fi
done
if [[ $ok -ne 1 ]]; then
  echo "FAIL: $IP never appeared in the $MODE firewall state"
  systemctl status "$SERVICE" --no-pager -l | tail -20 || true
  exit 1
fi

# The Docker-published Mailcow ports pass the forward path, so the drop must be reachable from there.
if [[ $MODE == nftables ]]; then
  ruleset=$(nft list ruleset)
  if ! grep -qE 'hook forward' <<<"$(awk -v t="table ip $TABLE " 'index($0,t)==1,/^}/' <<<"$ruleset")"; then
    echo "FAIL: no forward hook in table ip $TABLE: bans would not block Docker-published ports"
    echo "$ruleset" | head -60
    exit 1
  fi
else
  if ! iptables -S DOCKER-USER | grep -qi crowdsec; then
    echo "FAIL: no CrowdSec rule in DOCKER-USER: bans would not block Docker-published ports"
    iptables -S | head -60
    exit 1
  fi
fi
if connects; then echo "FAIL: $IP is banned but still reaches a Docker-published port"; exit 1; fi

# Removing the decision must remove the rule again
docker exec crowdsec-mailcow cscli decisions delete --ip "$IP" >/dev/null
for _ in $(seq 1 30); do
  sleep 2
  banned && continue
  connects || { echo "FAIL: $IP still cannot reach the published port after the decision was deleted"; exit 1; }
  echo "PASS ($MODE): banned traffic dropped on the forward path, let through again once lifted"
  exit 0
done
echo "FAIL: $IP still known to the firewall after the decision was deleted"
exit 1
