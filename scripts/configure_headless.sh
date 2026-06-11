#!/bin/bash
# RaspyJack Headless Configuration Helper
#
# Run this once after flashing a new SD card to set up your personal details.
# Writes config/headless.json — this file is gitignored and never shared.
#
# Usage:
#   sudo bash /root/Raspyjack/scripts/configure_headless.sh

set -euo pipefail

PROJECT_ROOT="/root/Raspyjack"
CONFIG_FILE="${PROJECT_ROOT}/config/headless.json"
CONFIG_EXAMPLE="${PROJECT_ROOT}/config/headless.json.example"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   RaspyJack — First-Time Headless Setup      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "This will create ${CONFIG_FILE}"
echo "with your personal settings (WiFi, hostname, etc)."
echo "This file is gitignored and will never be committed."
echo ""

# --- Prompt helpers ---

prompt() {
    local var="$1" msg="$2" default="$3"
    local val
    if [[ -n "$default" ]]; then
        read -rp "  ${msg} [${default}]: " val
        val="${val:-$default}"
    else
        while true; do
            read -rp "  ${msg}: " val
            [[ -n "$val" ]] && break
            echo "  (required — cannot be empty)"
        done
    fi
    printf -v "$var" '%s' "$val"
}

prompt_secret() {
    local var="$1" msg="$2"
    local val
    while true; do
        read -rsp "  ${msg}: " val
        echo ""
        [[ -n "$val" ]] && break
        echo "  (required — cannot be empty)"
    done
    printf -v "$var" '%s' "$val"
}

prompt_yn() {
    local var="$1" msg="$2" default="${3:-n}"
    local val
    read -rp "  ${msg} [y/N]: " val
    val="${val:-$default}"
    if [[ "$val" =~ ^[Yy] ]]; then
        printf -v "$var" 'true'
    else
        printf -v "$var" 'false'
    fi
}

# --- Gather input ---

echo "── WiFi (the network the Pi will connect to as a client) ──"
prompt   WIFI_SSID     "WiFi SSID (hotspot name)"       ""
prompt_secret WIFI_PASS "WiFi password"

echo ""
echo "── Pi Identity ──"
prompt HOSTNAME "Hostname for this Pi" "raspyjack"

echo ""
echo "── Tailscale (optional — for remote access over the internet) ──"
prompt_yn TAILSCALE_ENABLED "Enable Tailscale?" "n"

TAILSCALE_KEY_FILE=""
if [[ "$TAILSCALE_ENABLED" == "true" ]]; then
    echo "  Generate a key at: https://login.tailscale.com/admin/settings/keys"
    echo "  Paste your auth key below (starts with tskey-auth-...)"
    read -rsp "  Tailscale auth key: " TS_KEY
    echo ""
    if [[ -n "$TS_KEY" ]]; then
        TAILSCALE_KEY_FILE="${PROJECT_ROOT}/config/.tailscale_auth_key"
        echo "$TS_KEY" > "$TAILSCALE_KEY_FILE"
        chmod 600 "$TAILSCALE_KEY_FILE"
        echo "  Key saved to ${TAILSCALE_KEY_FILE}"
    fi
fi

echo ""
echo "── Fan Control (optional) ──"
echo "  If you have a fan wired through a MOSFET (recommended: IRLZ44N low-side on GPIO 18),"
echo "  this payload will automatically adjust fan speed based on CPU temperature."
echo ""
echo "  ⚠️  Enabling fan control with NO fan/MOSFET connected is completely harmless."
echo "     The script will simply toggle the pin and log what it would do."
echo "     It is pointless but will not damage anything or cause errors."
prompt_yn FAN_ENABLED "Enable dynamic fan control?" "n"

FAN_PIN=18
FAN_MIN_TEMP=45
FAN_MAX_TEMP=70
FAN_MIN_DUTY=20
FAN_MAX_DUTY=100
if [[ "$FAN_ENABLED" == "true" ]]; then
    prompt FAN_PIN      "GPIO pin (safe: 17, 18, 27, 22)" "18"
    prompt FAN_MIN_TEMP "Min temp °C (fan starts)"        "45"
    prompt FAN_MAX_TEMP "Max temp °C (fan at 100%)"       "70"
    prompt FAN_MIN_DUTY "Min fan duty %"                  "20"
    prompt FAN_MAX_DUTY "Max fan duty %"                  "100"
fi

# --- Check for existing config ---

if [[ -f "$CONFIG_FILE" ]]; then
    echo ""
    echo "⚠️  A config file already exists at ${CONFIG_FILE}"
    read -rp "  Overwrite it with new settings? [y/N]: " _overwrite
    if [[ ! "$_overwrite" =~ ^[Yy] ]]; then
        echo ""
        echo "Keeping existing config. Run the setup script to apply it:"
        echo "  sudo ${PROJECT_ROOT}/payloads/utilities/raspyjack_headless_setup.sh"
        exit 0
    fi
fi

# --- Write config ---

cat > "$CONFIG_FILE" <<EOF
{
  "wifi": {
    "ssid": $(printf '%s' "$WIFI_SSID" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),
    "password": $(printf '%s' "$WIFI_PASS" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))")
  },

  "hostname": $(printf '%s' "$HOSTNAME" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),

  "network": {
    "prefer_wifi_over_ethernet": true
  },

  "tailscale": {
    "enabled": ${TAILSCALE_ENABLED},
    "auth_key_file": $(printf '%s' "$TAILSCALE_KEY_FILE" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))")
  },

  "fan_control": {
    "enabled": ${FAN_ENABLED},
    "pin": ${FAN_PIN},
    "min_temp_c": ${FAN_MIN_TEMP},
    "max_temp_c": ${FAN_MAX_TEMP},
    "min_duty": ${FAN_MIN_DUTY},
    "max_duty": ${FAN_MAX_DUTY}
  },

  "webui": {
    "create_default_user": false
  }
}
EOF

chmod 600 "$CONFIG_FILE"

echo ""
echo "✓ Config written to ${CONFIG_FILE}"
echo ""
echo "── Next steps ──"
echo "  1. Apply settings now:"
echo "     sudo ${PROJECT_ROOT}/payloads/utilities/raspyjack_headless_setup.sh"
echo ""
echo "  2. (Optional) Install as a boot service:"
echo "     sudo ${PROJECT_ROOT}/payloads/utilities/raspyjack_headless_setup.sh install-service"
echo ""
echo "  3. Connect from your phone/laptop:"
echo "     - Turn on your '${WIFI_SSID}' hotspot"
echo "     - Pi will connect and be reachable at: raspyjack.local"
echo "     - WebUI: http://raspyjack.local:8080"
echo "     - SSH:   ssh <your-pi-user>@raspyjack.local"
echo ""
