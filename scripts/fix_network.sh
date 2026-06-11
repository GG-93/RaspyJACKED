#!/usr/bin/env bash
# =============================================================================
# RaspyJACKED — Network Recovery Script
# =============================================================================
# Run this if:
#   - WebUI is unreachable after switching WiFi interfaces in the app
#   - Pi has no internet (Tailscale drops, payloads fail)
#   - "Destination Host Unreachable" or gateway unreachable errors
#   - nmcli shows wrong/stale gateway
#
# Usage:
#   sudo bash /root/Raspyjack/scripts/fix_network.sh [SSID]
#
# If SSID is omitted, it resets ALL known WiFi connections to DHCP.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[fix-network]${NC} $*"; }
warn() { echo -e "${YELLOW}[fix-network]${NC} $*"; }
err()  { echo -e "${RED}[fix-network]${NC} $*"; }

if [[ $EUID -ne 0 ]]; then
    err "Must run as root: sudo bash $0"
    exit 1
fi

TARGET_SSID="${1:-}"

# ── 1. Show current state ─────────────────────────────────────────────────────
log "Current network state:"
ip addr show | grep -E "^[0-9]+:|inet " | sed 's/^/  /'
echo ""
log "Current routes:"
ip route show | sed 's/^/  /'
echo ""
log "NetworkManager connections:"
nmcli -t -f NAME,TYPE,DEVICE,STATE con show | sed 's/^/  /'
echo ""

# ── 2. Reset specified or all WiFi connections to DHCP ───────────────────────
reset_connection() {
    local name="$1"
    local type
    type=$(nmcli -t -f connection.type con show "$name" 2>/dev/null | cut -d: -f2 || echo "")
    [[ "$type" != "802-11-wireless" ]] && return

    local current_method
    current_method=$(nmcli -t -f ipv4.method con show "$name" 2>/dev/null | cut -d: -f2 || echo "")

    if [[ "$current_method" == "manual" ]]; then
        warn "Connection '$name' has static IP — resetting to DHCP..."
        nmcli con modify "$name" \
            ipv4.method auto \
            ipv4.addresses "" \
            ipv4.gateway "" \
            ipv4.route-metric 50
        log "  ✓ '$name' reset to DHCP"
    else
        log "  '$name' is already DHCP — refreshing..."
    fi

    # Bounce the connection to pick up new gateway
    nmcli con down "$name" 2>/dev/null || true
    sleep 1
    nmcli con up "$name" 2>/dev/null && log "  ✓ '$name' reconnected" || warn "  Could not bring up '$name' — may not be in range"
}

if [[ -n "$TARGET_SSID" ]]; then
    log "Resetting connection: $TARGET_SSID"
    reset_connection "$TARGET_SSID"
else
    log "Resetting all WiFi connections to DHCP..."
    while IFS= read -r name; do
        reset_connection "$name"
    done < <(nmcli -t -f NAME,TYPE con show | awk -F: '$2=="802-11-wireless"{print $1}')
fi

# ── 3. Remove duplicate WiFi profiles for same SSID ─────────────────────────
log "Checking for duplicate WiFi profiles..."
declare -A seen_ssids
while IFS= read -r line; do
    name=$(echo "$line" | cut -d: -f1)
    ssid=$(nmcli -t -f 802-11-wireless.ssid con show "$name" 2>/dev/null | cut -d: -f2 || echo "")
    [[ -z "$ssid" ]] && continue
    if [[ -n "${seen_ssids[$ssid]+x}" ]]; then
        warn "  Removing duplicate profile '$name' for SSID '$ssid'"
        nmcli con delete "$name" 2>/dev/null || true
    else
        seen_ssids[$ssid]="$name"
    fi
done < <(nmcli -t -f NAME,TYPE con show | awk -F: '$2=="802-11-wireless"{print $1": "$2}' | sed 's/: 802-11-wireless//')

# ── 4. Fix default route if missing ──────────────────────────────────────────
sleep 3
DEFAULT_ROUTE=$(ip route show default 2>/dev/null | head -1 || echo "")
if [[ -z "$DEFAULT_ROUTE" ]]; then
    warn "No default route! Trying to re-establish..."
    # Find first connected WiFi and force route via its gateway
    IFACE=$(nmcli -t -f DEVICE,STATE dev status | awk -F: '$2=="connected" && $1~/wlan/{print $1; exit}')
    if [[ -n "$IFACE" ]]; then
        GW=$(ip route show dev "$IFACE" | grep -v "^default" | awk '{print $1}' | head -1 | sed 's|/.*||' | awk -F. 'BEGIN{OFS="."}{$NF=1; print}')
        if [[ -n "$GW" ]]; then
            ip route add default via "$GW" dev "$IFACE" metric 100 2>/dev/null && log "  ✓ Default route restored via $GW on $IFACE" || warn "  Could not restore default route"
        fi
    fi
else
    log "Default route OK: $DEFAULT_ROUTE"
fi

# ── 5. Restart Tailscale if installed ────────────────────────────────────────
if command -v tailscale >/dev/null 2>&1; then
    TS_STATUS=$(tailscale status 2>&1 | head -1 || echo "")
    if echo "$TS_STATUS" | grep -q "logged out\|NoState\|NeedsLogin"; then
        warn "Tailscale is logged out — reconnecting..."
        # Get saved flags from running config if available
        tailscale up --accept-routes 2>&1 | head -5 || true
    else
        log "Tailscale: $TS_STATUS"
    fi
else
    warn "Tailscale not installed — skipping"
fi

# ── 6. Show final state ───────────────────────────────────────────────────────
echo ""
log "=== Final state ==="
ip addr show | grep -E "inet " | grep -v "127.0.0.1\|::1" | sed 's/^/  /'
ip route show default | sed 's/^/  Default route: /'
echo ""

WIFI_IP=$(ip -4 addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 || echo "")
ETH_IP=$(ip -4 addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 || echo "")
TS_IP=$(ip -4 addr show tailscale0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 || echo "")

log "=== WebUI Access ==="
[[ -n "$WIFI_IP"  ]] && log "  WiFi:      http://${WIFI_IP}:8080"
[[ -n "$ETH_IP"   ]] && log "  Ethernet:  http://${ETH_IP}:8080"
[[ -n "$TS_IP"    ]] && log "  Tailscale: http://${TS_IP}:8080"
log "  mDNS:      http://raspyjack.local:8080"
echo ""
log "Done. If still unreachable, check phone hotspot AP isolation (use Tailscale or mDNS)."
