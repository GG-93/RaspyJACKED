# RaspyJack Field Guide: Headless Operation on Raspberry Pi 4B

**Target Hardware**: Raspberry Pi 4B (no display, no HAT)  
**Power**: Battery bank  
**Cooling**: Fan controlled via IRLZ44N MOSFET on GPIO 18  
**Primary Use**: Portable wardriving, monitoring, and payload execution while connected as a WiFi client to a phone or laptop hotspot (e.g. MyHotspot or any SSID you choose).

This is a practical field reference. Jump to any section. It assumes you know nothing about penetration testing.

---

## 1. Quick Start

1. Power on the Pi 4B.
2. Turn on your phone/laptop hotspot with the SSID and password configured in `config/headless.json`.
3. Wait 20–40 seconds.
4. On any device on the same hotspot, open a browser:
   - `http://raspyjack.local:8080`
   - or `http://<YOUR_STATIC_IP>:8080`
5. Log in to the WebUI.
6. Use the Payloads section to start/stop tools.
7. Monitor loot in the Loot browser.

For first-time setup on a new or cloned card, run:
```bash
sudo bash /root/Raspyjack/scripts/configure_headless.sh
```

Then reboot or run the setup script.

---

## 2. Hardware Setup with Wiring Diagrams

### Fan Control (IRLZ44N MOSFET)

**Correct pinout for IRLZ44N TO-220 package** (flat metal face toward you, pins pointing down, left to right):

- **Left pin (Gate)** → GPIO 18 (Pi Pin 12)
- **Middle pin (Drain)** → Fan negative/black wire
- **Right pin (Source)** → Pi Ground (Pin 6 or any GND)

**Wiring summary**:
- Fan red (+) → Pi Pin 4 or 2 (5V)
- Fan black (-) → MOSFET Drain (middle pin)
- MOSFET Gate (left pin) → Pi GPIO 18 (Pin 12)
- MOSFET Source (right pin) → Pi GND (Pin 6)

**ASCII diagram** (front view, flat face toward you, pins down):

```
       IRLZ44N (TO-220)
          ____
         |    |
Gate ----|  G |---- (to Pi GPIO 18 / Pin 12)
         |    |
Drain ---|  D |---- (to Fan black / negative)
         |    |
Source --|  S |---- (to Pi GND / Pin 6)
         |____|
```

**Important**: This is the correct orientation. Gate on the left when flat face is toward you.

**Power connections for the fan**:
- Fan positive (red) must connect directly to 5V (Pi Pin 4 or 2).
- The MOSFET switches the ground side (low-side switching). This is the correct and safe way.

### Planned Shutdown Button

- One side of momentary tactile button → Pi Pin 11 (GPIO 17)
- Other side → Pi Pin 9 (GND)

The script requires a 2-second hold to prevent accidental shutdown.

---

## 3. First Time Configuration

Run this on every new or cloned SD card:

```bash
sudo bash /root/Raspyjack/scripts/configure_headless.sh
```

This creates `/root/Raspyjack/config/headless.json` (this file is gitignored and must never be committed).

The script asks for:
- WiFi SSID + password (the network the Pi will join as a client — any SSID works)
- Hostname
- Tailscale details (optional)
- Fan control settings (pin, temperatures, duty)

After running, the actual setup happens via:

```bash
/root/Raspyjack/payloads/utilities/raspyjack_headless_setup.sh
```

To make everything start automatically on boot:

```bash
/root/Raspyjack/payloads/utilities/raspyjack_headless_setup.sh install-service
```

---

## 4. Daily Use / Wardriving Workflow

1. Power on the Pi (battery bank).
2. Turn on your phone hotspot (matching SSID).
3. Wait 20–40 seconds.
4. Open browser on phone/laptop to WebUI.
5. Launch payloads from the Payloads menu (simple Start/Stop buttons — no need for the LCD replica interface).
6. Monitor in real time.
7. Check loot in the Loot browser or via SSH.
8. When finished, stop payloads and safely shut down.

**Wardriving specific**:
- Use external USB WiFi adapters in monitor mode (built-in WiFi on Pi 4B is usually not sufficient).
- Launch the wardriving payload from WebUI.
- Use `mobile_gps.py` payload + phone browser for GPS (no extra GPS module needed).
- Data is saved to `/root/Raspyjack/loot/wardriving/`

---

## 5. Connection Methods Reference Table

| Method          | Address                                      | Requirements                     | Best For                  |
|-----------------|----------------------------------------------|----------------------------------|---------------------------|
| mDNS            | http://raspyjack.local:8080                  | Same network                     | Local convenience         |
| Static IP       | http://<YOUR_STATIC_IP>:8080                      | Static IP configured             | Most reliable local       |
| Tailscale       | http://<YOUR_TAILSCALE_IP>/ or Magic DNS            | Tailscale running on your device | Remote access anywhere    |
| USB Direct      | http://172.20.2.1/                           | USB-C OTG cable to host          | Zero middleman, physical access |
| SSH (local)     | ssh <youruser>@raspyjack.local               | SSH client                       | Full control & debugging  |
| SSH (Tailscale) | ssh <youruser>@<YOUR_TAILSCALE_IP>                  | Tailscale                        | Remote full control       |

---

## 6. GPIO Pin Reference

**Dangerous pins (HAT button pins — never use for custom hardware)**: 5, 6, 13, 16, 19, 20, 21, 26

**Safe pins recommended for Pi 4B headless**:
- GPIO 17 (Pin 11) – Shutdown button
- GPIO 18 (Pin 12) – Fan control (hardware PWM)
- 22, 23, 24, 27 – Safe for other projects

---

## 7. Fan Control

### With IRLZ44N MOSFET (Current Wiring)

- Controlled by `dynamic_fan_control.py` reading from `headless.json`
- Behavior (example): off below 50°C, ramps up above 55°C, full speed at 70°C+
- Uses hardware PWM on GPIO 18 for smooth operation.

**Important note about 3-wire fans**:
If your fan has three wires and runs at full speed while ignoring software commands, the third wire is almost certainly a **tachometer output** (speed sensor), not a PWM input. In this case you must switch the **power line** (positive or negative) with the MOSFET — not the tachometer wire. Switching the wrong wire will have no effect on speed.

### Without MOSFET

The fan will either run continuously (if wired directly to 5V) or the control script will run harmlessly in simulation mode and simply log what it would have done. No damage occurs, but you lose variable speed control.

---

## 8. Shutdown Button Installation

The script is located at:

`scripts/shutdown_button.py`

**Installation steps**:

1. From your computer, copy the script to the Pi:

```bash
scp scripts/shutdown_button.py <user>@<YOUR_STATIC_IP>:/root/Raspyjack/scripts/
# or via Tailscale
scp scripts/shutdown_button.py <user>@<YOUR_TAILSCALE_IP>:/root/Raspyjack/scripts/
```

2. On the Pi, make it executable:

```bash
chmod +x /root/Raspyjack/scripts/shutdown_button.py
```

3. Create the systemd service file:

```bash
sudo tee /etc/systemd/system/raspyjack-shutdown.service > /dev/null <<EOF
[Unit]
Description=RaspyJack Safe Shutdown Button
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /root/Raspyjack/scripts/shutdown_button.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

4. Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable raspyjack-shutdown.service
sudo systemctl start raspyjack-shutdown.service
```

The button requires a **2-second hold** to trigger shutdown (prevents accidental presses).

---

## 9. Static IP Setup

To make the Pi always use the same IP on your WiFi network (highly recommended for field reliability):

```bash
sudo nmcli connection modify "YourSSID" ipv4.method manual \
  ipv4.addresses <YOUR_STATIC_IP>/24 \
  ipv4.gateway <YOUR_GATEWAY_IP> \
  ipv4.dns '8.8.8.8 1.1.1.1' \
  && sudo nmcli connection up "YourSSID"
```

This change survives reboots. Replace `YourSSID` with the actual SSID and adjust the IP/gateway as needed for your network.

---

## 10. Tailscale Setup

Tailscale is optional but excellent for remote access.

During first-time setup with `configure_headless.sh`, enable it and paste an auth key.

Manual one-time setup:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --authkey=tskey-auth-... --ssh
```

Once running, the Pi is reachable from any Tailscale device using its stable IP or Magic DNS name. No port forwarding required.

Tailscale is **not required** for normal local use on the same WiFi network as the Pi.

---

## 11. Services Cheatsheet

All four main services should be enabled and running:

**raspyjack-device.service** (core device communication)
```bash
sudo systemctl start raspyjack-device.service
sudo systemctl stop raspyjack-device.service
sudo systemctl restart raspyjack-device.service
sudo systemctl status raspyjack-device.service
```

**raspyjack-webui.service** (WebUI at port 8080)
```bash
sudo systemctl start raspyjack-webui.service
sudo systemctl stop raspyjack-webui.service
sudo systemctl restart raspyjack-webui.service
sudo systemctl status raspyjack-webui.service
```

**raspyjack-fan.service** (dynamic fan control)
```bash
sudo systemctl start raspyjack-fan.service
sudo systemctl stop raspyjack-fan.service
sudo systemctl restart raspyjack-fan.service
sudo systemctl status raspyjack-fan.service
```

**tailscaled.service** (Tailscale)
```bash
sudo systemctl start tailscaled.service
sudo systemctl stop tailscaled.service
sudo systemctl restart tailscaled.service
sudo systemctl status tailscaled.service
```

**Useful one-liners**:
```bash
sudo systemctl restart raspyjack-device.service raspyjack-webui.service
sudo systemctl status raspyjack-*.service tailscaled.service
journalctl -u raspyjack-webui.service -f
```

---

## 12. Wardriving and Loot

### How Wardriving Works

RaspyJack uses external USB WiFi adapters in monitor mode to scan for networks. The main payload is `reconnaissance/wardriving.py`.

It logs:
- BSSID, SSID, security type, signal strength, channel
- GPS coordinates (when available)
- Timestamps

Exports to Wigle-compatible CSV, JSON, and KML.

### GPS Without a Hardware Module

Use the `hardware/mobile_gps.py` payload:
1. Start it on the Pi.
2. On your phone (on the same hotspot), open the web page it serves (usually port 4443).
3. Allow location access in the browser.
4. The phone continuously sends GPS data to the Pi over the local network.

This works whether your phone or a laptop is providing the hotspot.

### Loot Files and Retrieval

Loot is stored in `/root/Raspyjack/loot/`

Common subdirectories:
- `wardriving/` – Network logs, Wigle CSVs, KML files
- `recon/` – Nmap scans, device lists
- `credentials/` – Captured credentials
- `wifi/` – Handshakes and PMKID files
- `GPS/` – GPS track logs from mobile_gps.py

**To retrieve loot** (from your computer):

```bash
# Using static IP
scp -r <user>@<YOUR_STATIC_IP>:/root/Raspyjack/loot/ ./raspyjack-loot/

# Using Tailscale
scp -r <user>@<YOUR_TAILSCALE_IP>:/root/Raspyjack/loot/ ./raspyjack-loot/

# Using mDNS (when on same network)
scp -r <user>@raspyjack.local:/root/Raspyjack/loot/ ./raspyjack-loot/
```

You can also browse and download individual files through the WebUI Loot section.

---

## 13. Troubleshooting

**Cannot reach the WebUI**
- Confirm your device is on the same hotspot.
- Try the static IP directly.
- Check services are running (see Services Cheatsheet).

**Fan not responding to software**
- Verify MOSFET wiring (Gate-Drain-Source orientation).
- If using a 3-wire fan and it ignores commands, the third wire is a tachometer — move the MOSFET to the power line.

**Fan always at full speed**
- Most likely no MOSFET or wiring on the wrong wire.

**Tailscale not connecting**
- Confirm the hotspot has internet.
- Check `tailscale status` via SSH.
- Re-authenticate if the key expired.

**High CPU / overheating**
- Confirm fan service is running and the fan is actually spinning.
- Check for stuck payloads.

---

## 14. Giving a Card to a Friend (Handoff)

1. Start with a fresh or your latest image.
2. Have the recipient run `sudo bash /root/Raspyjack/scripts/configure_headless.sh` and enter **their** details.
3. Never commit `headless.json`.
4. Delete or reset personal files before handing over:
   - `config/headless.json`
   - Any Tailscale auth key files
   - `.webui_auth.json`
5. Provide this FIELD_GUIDE.md and `FORK_DIFFERENCES.md`.

The recipient only needs to know their own SSID/password and (optionally) a Tailscale key.

---

## 15. Approaching the Upstream Developer

When ready to discuss contributing this headless layer:

- Reference this FIELD_GUIDE.md and FORK_DIFFERENCES.md.
- Emphasize that the work is additive and does not break existing LCD-based usage.
- Highlight real-world field use on Pi 4B (battery, no display, long deployments, fan control, USB gadget as direct option).
- Note that the installer already disables hostapd by default, making client-only headless a natural fit.
- Be prepared to discuss GPIO safety and the configuration-driven approach.

---

**End of Field Guide**

This document is intended for offline use in the field. Update it as your setup evolves. All commands assume you have WebUI or SSH access to the Pi.

Good luck. Stay safe and authorized.