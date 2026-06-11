#!/bin/bash
# Deploy headless mode to a running Pi.
# Run from your Mac: bash scripts/deploy_headless.sh <pi-ip> <pi-user>
# Example: bash scripts/deploy_headless.sh 192.168.1.100 pi

set -euo pipefail

PI_IP="${1:-YOUR_PI_IP}"
PI_USER="${2:-pi}"
RJ="/root/Raspyjack"

echo "==> Deploying headless mode to ${PI_USER}@${PI_IP}"

# Copy updated files
echo "==> Copying LCD_1in44.py..."
scp LCD_1in44.py "${PI_USER}@${PI_IP}:/tmp/LCD_1in44.py"

echo "==> Installing files and configuring services..."
ssh "${PI_USER}@${PI_IP}" "sudo bash -s" << 'EOF'
RJ="/root/Raspyjack"

# Deploy LCD driver
cp /tmp/LCD_1in44.py ${RJ}/LCD_1in44.py

# Add RJ_DISPLAY_TYPE=HEADLESS to raspyjack-device service if not already there
SERVICE=/etc/systemd/system/raspyjack-device.service
if ! grep -q "RJ_DISPLAY_TYPE" "$SERVICE"; then
    sed -i '/^\[Service\]/a Environment=RJ_DISPLAY_TYPE=HEADLESS' "$SERVICE"
    echo "  Added RJ_DISPLAY_TYPE=HEADLESS to raspyjack-device.service"
else
    echo "  RJ_DISPLAY_TYPE already set"
fi

# Detect and inject RJ_MGMT_IFACE so payloads know which interface not to disrupt
MGMT_IFACE=""
CONFIG_FILE="${RJ}/config/headless.json"
if [ -f "$CONFIG_FILE" ] && command -v python3 >/dev/null 2>&1; then
    IFACE_PREF=$(python3 -c "import json; d=json.load(open('$CONFIG_FILE')); print(d.get('wifi',{}).get('interface','auto'))" 2>/dev/null || echo "auto")
else
    IFACE_PREF="auto"
fi
if [ "$IFACE_PREF" != "auto" ] && [ -n "$IFACE_PREF" ]; then
    MGMT_IFACE="$IFACE_PREF"
else
    # Mirror detect_wifi_interface: prefer USB dongle over onboard
    for dev in /sys/class/net/wlan*; do
        [ -e "$dev" ] || continue
        iface="$(basename "$dev")"
        devpath="$(readlink -f "$dev/device" 2>/dev/null || true)"
        if echo "$devpath" | grep -q "usb"; then
            MGMT_IFACE="$iface"
            break
        elif echo "$devpath" | grep -q "mmc\|platform"; then
            [ -z "$MGMT_IFACE" ] && MGMT_IFACE="$iface"
        fi
    done
    [ -z "$MGMT_IFACE" ] && MGMT_IFACE="wlan0"
fi
echo "  Management interface detected: $MGMT_IFACE"
for SVC_FILE in \
    /etc/systemd/system/raspyjack-device.service \
    /etc/systemd/system/raspyjack-webui.service; do
    [ -f "$SVC_FILE" ] || continue
    if ! grep -q "RJ_MGMT_IFACE" "$SVC_FILE"; then
        sed -i "/^\[Service\]/a Environment=RJ_MGMT_IFACE=${MGMT_IFACE}" "$SVC_FILE"
        echo "  Injected RJ_MGMT_IFACE=${MGMT_IFACE} into $(basename $SVC_FILE)"
    else
        # Update the value in case the interface changed
        sed -i "s|Environment=RJ_MGMT_IFACE=.*|Environment=RJ_MGMT_IFACE=${MGMT_IFACE}|" "$SVC_FILE"
        echo "  Updated RJ_MGMT_IFACE=${MGMT_IFACE} in $(basename $SVC_FILE)"
    fi
done

# Create raspyjack-main service if it doesn't exist
if [ ! -f /etc/systemd/system/raspyjack-main.service ]; then
    cat > /etc/systemd/system/raspyjack-main.service << 'SERVICE'
[Unit]
Description=RaspyJack Main TUI (headless)
After=raspyjack-device.service raspyjack-webui.service
Wants=raspyjack-device.service raspyjack-webui.service

[Service]
Type=simple
WorkingDirectory=/root/Raspyjack
ExecStart=/usr/bin/python3 /root/Raspyjack/raspyjack.py
Environment=RJ_DISPLAY_TYPE=HEADLESS
Restart=on-failure
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
SERVICE
    echo "  Created raspyjack-main.service"
fi

systemctl daemon-reload
systemctl enable raspyjack-main.service
systemctl restart raspyjack-device.service
systemctl start raspyjack-main.service
sleep 2
systemctl is-active raspyjack-main.service && echo "  raspyjack-main: running" || echo "  raspyjack-main: FAILED - check: journalctl -u raspyjack-main -n 20"
systemctl is-active raspyjack-device.service && echo "  raspyjack-device: running"
EOF

echo ""
echo "==> Done. Test your WebUI screen mirror and Cardputer app."
echo "    WebUI: http://${PI_IP}:8080"
echo "    Check logs: ssh ${PI_USER}@${PI_IP} 'sudo journalctl -u raspyjack-main -n 30'"
