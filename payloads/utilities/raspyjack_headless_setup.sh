#!/bin/bash
# RaspyJack Portable Headless Setup
#
# Designed for cloned SD cards and easy handoff.
# Reads all user-specific settings from config/headless.json
#
# Usage:
#   sudo ./payloads/utilities/raspyjack_headless_setup.sh
#   sudo ./payloads/utilities/raspyjack_headless_setup.sh validate-config
#   sudo ./payloads/utilities/raspyjack_headless_setup.sh install-service

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/root/Raspyjack"

CONFIG_FILE="${PROJECT_ROOT}/config/headless.json"
CONFIG_EXAMPLE="${PROJECT_ROOT}/config/headless.json.example"

print_header() {
    echo "========================================"
    echo " RaspyJack Portable Headless Setup"
    echo "========================================"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# --- Config Loading with Validation ---

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        if [[ -f "$CONFIG_EXAMPLE" ]]; then
            echo ""
            echo "════════════════════════════════════════════════════════════"
            echo " FIRST BOOT / HANDOFF DETECTED"
            echo "════════════════════════════════════════════════════════════"
            echo ""
            echo "No config/headless.json found."
            echo "Please copy the example and fill in your details:"
            echo ""
            echo "    cp ${CONFIG_EXAMPLE} ${CONFIG_FILE}"
            echo "    nano ${CONFIG_FILE}     # or use any editor"
            echo ""
            echo "Then re-run this script."
            echo ""
            echo "Required fields at minimum:"
            echo "  - wifi.ssid"
            echo "  - wifi.password"
            echo ""
            die "Configuration file missing or not customized"
        else
            die "Neither ${CONFIG_FILE} nor ${CONFIG_EXAMPLE} found"
        fi
    fi

    # Try jq first (best), then python (usually available), then very basic fallback
    if command -v jq >/dev/null 2>&1; then
        parse_with_jq
    elif command -v python3 >/dev/null 2>&1; then
        parse_with_python
    else
        echo "WARNING: Neither jq nor python3 found. Using very basic parser."
        parse_with_grep
    fi

    validate_required_fields
}

parse_with_jq() {
    WIFI_SSID=$(jq -r '.wifi.ssid // empty' "$CONFIG_FILE")
    WIFI_PASS=$(jq -r '.wifi.password // empty' "$CONFIG_FILE")
    HOSTNAME=$(jq -r '.hostname // "raspyjack"' "$CONFIG_FILE")
    PREFER_WIFI=$(jq -r '.network.prefer_wifi_over_ethernet // true' "$CONFIG_FILE")
    WIFI_IFACE_PREF=$(jq -r '.wifi.interface // "auto"' "$CONFIG_FILE")
    TAILSCALE_ENABLED=$(jq -r '.tailscale.enabled // false' "$CONFIG_FILE")
    TAILSCALE_KEY_FILE=$(jq -r '.tailscale.auth_key_file // ""' "$CONFIG_FILE")
    FAN_ENABLED=$(jq -r '.fan_control.enabled // false' "$CONFIG_FILE")
    FAN_PIN=$(jq -r '.fan_control.pin // 18' "$CONFIG_FILE")
}

parse_with_python() {
    local json
    json=$(cat "$CONFIG_FILE")

    WIFI_SSID=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('wifi', {}).get('ssid', ''))
" <<< "$json")

    WIFI_PASS=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('wifi', {}).get('password', ''))
" <<< "$json")

    HOSTNAME=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('hostname', 'raspyjack'))
" <<< "$json")

    TAILSCALE_ENABLED=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
print(str(data.get('tailscale', {}).get('enabled', False)).lower())
" <<< "$json")

    TAILSCALE_KEY_FILE=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('tailscale', {}).get('auth_key_file', ''))
" <<< "$json")

    FAN_ENABLED=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
print(str(data.get('fan_control', {}).get('enabled', False)).lower())
" <<< "$json")

    FAN_PIN=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('fan_control', {}).get('pin', 18))
" <<< "$json")

    PREFER_WIFI=true
    WIFI_IFACE_PREF=auto
}

parse_with_grep() {
    WIFI_SSID=$(grep -o '"ssid"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | cut -d'"' -f4 || echo "")
    WIFI_PASS=$(grep -o '"password"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | cut -d'"' -f4 || echo "")
    HOSTNAME=$(grep -o '"hostname"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | cut -d'"' -f4 || echo "raspyjack")
    TAILSCALE_ENABLED=false
    TAILSCALE_KEY_FILE=""
    FAN_ENABLED=false
    FAN_PIN=18
    PREFER_WIFI=true
    WIFI_IFACE_PREF=auto
}

validate_required_fields() {
    local errors=0

    if [[ -z "${WIFI_SSID:-}" ]]; then
        echo "ERROR: wifi.ssid is missing or empty in config"
        errors=$((errors + 1))
    fi

    if [[ -z "${WIFI_PASS:-}" ]]; then
        echo "ERROR: wifi.password is missing or empty in config"
        errors=$((errors + 1))
    fi

    if [[ "$TAILSCALE_ENABLED" == "true" && ! -f "${TAILSCALE_KEY_FILE:-}" ]]; then
        echo "WARNING: tailscale.enabled is true but auth key file not found: ${TAILSCALE_KEY_FILE}"
    fi

    if [[ $errors -gt 0 ]]; then
        die "Config validation failed with $errors error(s). Please fix ${CONFIG_FILE}"
    fi
}

validate_config_only() {
    load_config
    local iface
    iface=$(detect_wifi_interface)
    echo "✓ Config looks valid"
    echo "  WiFi SSID:        ${WIFI_SSID}"
    echo "  WiFi Interface:   ${iface} (pref: ${WIFI_IFACE_PREF})"
    echo "  Hostname:         ${HOSTNAME}"
    echo "  Tailscale:        ${TAILSCALE_ENABLED}"
    echo "  Fan Control:      ${FAN_ENABLED} (pin ${FAN_PIN})"
    exit 0
}

# --- Core Setup Functions ---

# Detect which WiFi interface to use for the management (hotspot) connection.
# - "auto": prefer USB dongle (wlan1+) if present, fall back to onboard (wlan0)
# - "wlan0" / "wlan1" / etc: use exactly that interface
# Returns the interface name via stdout.
detect_wifi_interface() {
    local pref="${WIFI_IFACE_PREF:-auto}"

    if [[ "$pref" != "auto" ]]; then
        # Explicit preference — verify it exists
        if ip link show "$pref" >/dev/null 2>&1; then
            echo "$pref"
            return
        fi
        echo "WARNING: Requested interface '$pref' not found, falling back to auto-detect." >&2
    fi

    # Auto-detect: scan /sys/class/net for WiFi interfaces, prefer USB over onboard
    local usb_iface="" onboard_iface=""
    for dev in /sys/class/net/wlan*; do
        [[ -e "$dev" ]] || continue
        local iface devpath
        iface="$(basename "$dev")"
        devpath="$(readlink -f "$dev/device" 2>/dev/null || true)"
        if echo "$devpath" | grep -q "usb"; then
            # Pick the first USB dongle found (works on any port)
            [[ -z "$usb_iface" ]] && usb_iface="$iface"
        elif echo "$devpath" | grep -q "mmc\|platform"; then
            [[ -z "$onboard_iface" ]] && onboard_iface="$iface"
        fi
    done

    if [[ -n "$usb_iface" ]]; then
        echo "  [auto] USB dongle detected: $usb_iface (preferred over onboard)" >&2
        echo "$usb_iface"
    elif [[ -n "$onboard_iface" ]]; then
        echo "  [auto] No USB dongle found, using onboard: $onboard_iface" >&2
        echo "$onboard_iface"
    else
        echo "  [auto] No wlan interfaces found, defaulting to wlan0" >&2
        echo "wlan0"
    fi
}

setup_network() {
    print_header
    echo "Configuring WiFi client connection..."

    local iface
    iface=$(detect_wifi_interface)
    echo "  Using interface: $iface"

    # Remove ALL existing profiles for this SSID to prevent accumulation
    while nmcli -t -f NAME,TYPE con show | awk -F: '$2=="802-11-wireless"{print $1}' | \
          xargs -I{} sh -c 'nmcli -t -f 802-11-wireless.ssid con show "{}" 2>/dev/null | grep -qF "'"$WIFI_SSID"'" && echo "{}"' | \
          grep -q .; do
        local old_name
        old_name=$(nmcli -t -f NAME,TYPE con show | awk -F: '$2=="802-11-wireless"{print $1}' | \
                   xargs -I{} sh -c 'nmcli -t -f 802-11-wireless.ssid con show "{}" 2>/dev/null | grep -qF "'"$WIFI_SSID"'" && echo "{}"' | head -1)
        [[ -z "$old_name" ]] && break
        echo "  Removing old profile: $old_name"
        nmcli connection delete "$old_name" 2>/dev/null || break
    done

    # Add fresh connection — DHCP only, no static IP, no hardcoded gateway
    nmcli connection add \
        type wifi \
        ifname "$iface" \
        con-name "$WIFI_SSID" \
        ssid "$WIFI_SSID" \
        autoconnect yes \
        autoconnect-priority 100 \
        ipv4.method auto \
        ipv4.route-metric 50 \
        802-11-wireless-security.key-mgmt wpa-psk \
        802-11-wireless-security.psk "$WIFI_PASS" >/dev/null 2>&1 || true

    if [[ "$PREFER_WIFI" == "true" ]]; then
        for profile in "Wired connection 1" "Wired connection 2" "eth0" "netplan-eth0"; do
            nmcli connection modify "$profile" ipv4.route-metric 200 2>/dev/null || true
        done
    fi

    # Bring up with a timeout — don't hang forever if hotspot is off
    echo "  Connecting to '$WIFI_SSID'..."
    if nmcli connection up "$WIFI_SSID" --wait-device-timeout 15 2>/dev/null; then
        local ip
        ip=$(ip -4 addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 || echo "")
        echo "  Connected — IP: ${ip:-pending}"
    else
        echo "  WARNING: Could not connect to '$WIFI_SSID' right now."
        echo "  The profile is saved — Pi will auto-connect when hotspot is in range."
    fi

    echo "WiFi client configuration complete."
    echo "  Access WebUI at: http://raspyjack.local:8080"
}

set_hostname() {
    print_header
    echo "Setting hostname to '${HOSTNAME}'..."

    hostnamectl set-hostname "$HOSTNAME" 2>/dev/null || true
    sed -i "s/127.0.1.1.*/127.0.1.1\t${HOSTNAME}/" /etc/hosts 2>/dev/null || true
}

disable_main_ui() {
    print_header
    echo "Disabling main LCD UI service..."

    systemctl disable --now raspyjack.service 2>/dev/null || true
    systemctl enable --now raspyjack-device.service raspyjack-webui.service 2>/dev/null || true
    systemctl restart raspyjack-device.service raspyjack-webui.service 2>/dev/null || true
}

setup_tailscale() {
    if [[ "$TAILSCALE_ENABLED" != "true" ]]; then
        return
    fi

    print_header
    echo "Setting up Tailscale..."

    if ! command -v tailscale >/dev/null 2>&1; then
        curl -fsSL https://tailscale.com/install.sh | sh
    fi

    if [[ -n "${TAILSCALE_KEY_FILE}" && -f "${TAILSCALE_KEY_FILE}" ]]; then
        local key
        key=$(cat "${TAILSCALE_KEY_FILE}")
        sudo tailscale up --auth-key="$key" --ssh || true
    else
        echo "No auth key file found at ${TAILSCALE_KEY_FILE}"
        echo "Running interactive tailscale up (you may need to complete this manually)..."
        sudo tailscale up --ssh || true
    fi
}

show_status() {
    print_header
    echo "Current status:"
    echo "  Hostname: $(hostname)"
    echo ""
    ip -4 addr show | grep -E 'inet ' | grep -v '127.0.0.1' || true
    echo ""

    if command -v tailscale >/dev/null 2>&1; then
        local ts_ip
        ts_ip=$(tailscale ip -4 2>/dev/null || echo "not connected")
        echo "  Tailscale IPv4: $ts_ip"
    fi
}

install_service() {
    print_header
    echo "Installing systemd service..."

    local service_file="/etc/systemd/system/raspyjack-headless.service"
    local script_path="${PROJECT_ROOT}/payloads/utilities/raspyjack_headless_setup.sh"

    sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=RaspyJack Portable Headless Auto-Setup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${script_path}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable raspyjack-headless.service

    echo "Service installed and enabled."
    echo "It will run automatically on future boots."
}

main() {
    case "${1:-}" in
        validate-config)
            validate_config_only
            ;;
        install-service)
            load_config
            install_service
            ;;
        *)
            load_config
            disable_main_ui
            set_hostname
            setup_network
            setup_tailscale
            show_status
            echo ""
            echo "Run with 'install-service' to make this run automatically on boot."
            ;;
    esac
}

main "$@"