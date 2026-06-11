# Portable Headless Setup Guide

This document explains how to use the new portable headless system for RaspyJack.

The goal is to make it easy to:
- Run RaspyJack headlessly on a Pi 4 (no screen/keyboard)
- Connect reliably in two primary ways:
  1. **USB Direct** (no middleman) — Pi appears as USB Ethernet adapter (172.20.2.1)
  2. **WiFi Client** — Connects to any existing hotspot (phone, laptop, microcontroller, etc.)
- Use Tailscale (optional) as a stable overlay for remote access
- Easily customize everything via a single config file
- Clone SD cards and hand them to others with minimal effort

---

## Overview

The system consists of three main pieces:

1. **Config file**: `config/headless.json`
2. **Setup script**: `payloads/utilities/raspyjack_headless_setup.sh`
3. **Optional systemd service** to run automatically on every boot

All user-specific information (SSID, password, Tailscale key, hostname, fan settings, etc.) lives in the config file.

---

## Quick Start (First Time on a Card)

1. Boot the Pi (with or without Ethernet).
2. SSH in as root (or use the WebUI if you can discover the IP).
3. Copy and edit the config:

   ```bash
   cp /root/Raspyjack/config/headless.json.example /root/Raspyjack/config/headless.json
   nano /root/Raspyjack/config/headless.json
   ```

4. Fill in at minimum:
   - `wifi.ssid`
   - `wifi.password`

5. Run the setup:

   ```bash
   /root/Raspyjack/payloads/utilities/raspyjack_headless_setup.sh
   ```

6. (Recommended) Install the systemd service so it runs on every boot:

   ```bash
   /root/Raspyjack/payloads/utilities/raspyjack_headless_setup.sh install-service
   ```

---

## Configuration Reference

See `config/headless.json.example` for the full structure with comments.

Key sections:

- **wifi**: The WiFi network the Pi should join as a client
- **hostname**: What the Pi should call itself on the network
- **tailscale**: Enable automatic Tailscale connection (optional, requires internet)
- **fan_control**: Optional dynamic fan control using a safe GPIO pin
- **webui**: (Future) Options for WebUI user management

---

## Tailscale Integration (Recommended)

For reliable access without scanning for IPs every time, enable Tailscale in the config:

1. Generate an auth key at https://login.tailscale.com/admin/settings/keys (enable "Reusable" and "Ephemeral" if desired).
2. Save the key to a file (e.g. `/root/Raspyjack/config/.tailscale_auth_key`)
3. Set in `headless.json`:

```json
"tailscale": {
  "enabled": true,
  "auth_key_file": "/root/Raspyjack/config/.tailscale_auth_key"
}
```

The setup script will automatically bring Tailscale up using that key.

After this, you can reach the Pi from any device running Tailscale using:

- `http://raspyjack.your-tailnet.ts.net/`
- Or the stable Tailscale IPv4 address

**Connection Method 1 — WiFi Client (primary)**
- Pi connects to any WiFi network as a client (phone hotspot, travel router, microcontroller AP, etc.).
- Configure via `config/headless.json` (`wifi.ssid` / `wifi.password`).
- Assign a static IP via `nmcli` so the address never changes (see Quick Start above).
- Also reachable via mDNS: `raspyjack.local` (no IP lookup needed on the same network).

**Connection Method 2 — Tailscale (optional, requires internet)**
- Install Tailscale on the Pi (`curl -fsSL https://tailscale.com/install.sh | sh`) and run `sudo tailscale up`.
- Authenticate via your Tailscale account. Pi gets a stable VPN IP reachable from any device on the same Tailscale account.
- Magic DNS: `raspyjack.<your-tailnet>.ts.net`

SSH example:
```bash
ssh YOUR_USERNAME@raspyjack.local        # same local network
ssh YOUR_USERNAME@<your-tailscale-ip>   # via Tailscale from anywhere
```

---

## Making a Card for a Friend (Handoff Checklist)

When creating a clone for someone else:

1. Start from a card that has the latest version of this system.
2. **Delete or reset** these files:
   - `/root/Raspyjack/config/headless.json`
   - Any Tailscale auth key file
   - `/root/Raspyjack/.webui_auth.json` (WebUI users)
   - `/root/Raspyjack/.tailscale_auth_key` (if present)

3. Copy `config/headless.json.example` to `config/headless.json` with placeholder values (or leave the example).

4. Give the recipient clear instructions:
   - "Edit `config/headless.json` with your hotspot details and Tailscale key"
   - "Run the setup script once"
   - "Optionally run `install-service`"

This keeps your personal credentials out of the shared image.

---

## Development Notes

- The script tries to be as robust as possible on minimal Raspberry Pi OS installs.
- It prefers `jq` → `python3` → basic grep for JSON parsing.
- It is intentionally idempotent where possible (re-running it is generally safe).
- GPIO pin safety is handled separately (see fan control payload).

---

## Future Improvements (Tracked)

- Automatic creation of a default WebUI admin user from config
- Better integration with the existing WebUI for status and logs
- Support for multiple named configurations / profiles
- Automatic fan control service installation from the main setup

---

**Last updated:** 2026-05-31