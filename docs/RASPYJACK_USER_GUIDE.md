# RaspyJack User Guide

**Focused on Headless Operation on Raspberry Pi 4B**

This guide is written specifically for running **RaspyJack headless on a Raspberry Pi 4B**.

While RaspyJack originally targets handheld use with an LCD HAT (typically on a Pi Zero 2 W), this document focuses on the **headless Pi 4B** use case — where the device runs without a screen, is controlled primarily through the WebUI, and is often deployed for long-duration tasks such as wardriving, monitoring, or remote operations.

The Pi 4B offers significantly more CPU power, RAM, and USB capabilities than a Pi Zero, making it excellent for headless use, especially when combined with:
- A configurable WiFi client connection (to any hotspot)
- Optional Tailscale for stable remote access
- USB gadget mode for direct wired control
- Dynamic fan control for 24/7 reliability

---

**Note**: Traditional LCD + button usage is still supported and documented in relevant sections, but the primary focus of this guide is headless Pi 4B operation.

---

## Table of Contents

1. [Overview & Legal](#overview--legal)
2. [Hardware Requirements](#hardware-requirements)
3. [First Boot & Installation](#first-boot--installation)
4. [The Interface (LCD + Buttons)](#the-interface-lcd--buttons)
5. [WebUI & Payload IDE](#webui--payload-ide)
6. [How Payloads Work](#how-payloads-work)
7. [Payload Categories & Tools](#payload-categories--tools)
8. [Headless Operation](#headless-operation)
9. [Advanced Features](#advanced-features)
10. [Tips, Tricks & Best Practices](#tips-tricks--best-practices)

---

## 1. Overview & Legal

**RaspyJack** is a portable offensive security toolkit designed for the Raspberry Pi (especially the Pi Zero 2 W).

It combines:
- A handheld-style LCD interface with joystick and buttons
- Over 300 payloads across many categories
- A powerful WebUI with Payload IDE
- Integration with tools like Responder, Ragnar, and various WiFi attack suites

### Legal Warning

> **RaspyJack is for authorized security testing, research, and education only.**

You must have explicit permission to test any network, device, or system. Unauthorized use is illegal.

---

## 2. Hardware Requirements (Headless Pi 4B Focus)

This guide assumes the following primary setup:

### Recommended Headless Configuration (Pi 4B)
- **Raspberry Pi 4B** (2GB, 4GB, or 8GB)
- Good quality power supply (official 5V/3A+ recommended, especially with fan)
- microSD card (32GB+ Class 10 or better)
- Active cooling solution (mandatory for long-running/headless use):
  - 30mm or 40mm fan + heatsink
  - Recommended: Low-side MOSFET control (e.g. IRLZ44N on GPIO 18) + dynamic fan payload
- Case with ventilation or open-frame mounting

### Connectivity Options (Choose One or Combine)
1. **WiFi Client Mode** (most common)
   - Built-in WiFi connects to any hotspot (phone, laptop, travel router, etc.)
   - Highly recommended: Use the `configure_headless.sh` script + static IP

2. **USB Gadget Mode (Direct)**
   - Pi appears as a USB Ethernet adapter when connected to a host
   - Pi IP: `172.20.2.1`
   - Excellent for direct control without relying on WiFi

3. **Tailscale (Overlay)**
   - Strongly recommended for remote access from anywhere
   - Works on top of WiFi client mode

4. **USB Ethernet Adapter** (optional)
   - Useful backup or for higher bandwidth

### Display (Optional)
- No display required for headless use.
- The **WebUI** (`http://<ip>/` or `:8080`) is the primary interface.
- LCD HATs (1.44" or 1.3") can still be attached if desired for local control.

### Power & Cooling Notes for Pi 4B
- The Pi 4B runs significantly hotter than a Pi Zero under load.
- For 24/7 or long-duration deployments (e.g. wardriving), active cooling with fan control is strongly recommended.
- Use a quality power supply. Undervoltage can cause instability with WiFi + payloads.

---

## 3. First Boot & Installation

The official way to install is using the provided installer:

```bash
git clone https://github.com/7h30th3r0n3/Raspyjack.git
cd Raspyjack
sudo bash install_raspyjack.sh
```

During installation you will be asked:
- Which display you have (1.44", 1.3", or CardputerZero)
- Whether to install optional components

After installation, reboot. The main interface should launch automatically.

---

## 4. The Interface (LCD + Buttons)

### Controls (Waveshare 1.44" / 1.3" HAT)

| Button     | Action                          |
|------------|---------------------------------|
| **UP / DOWN** | Navigate menus               |
| **LEFT**      | Go back                      |
| **RIGHT / OK** | Enter / Select / Run        |
| **KEY1**      | Context action (varies)      |
| **KEY2**      | Secondary action             |
| **KEY3**      | Exit / Cancel / Back         |

Most payloads use **KEY3** as the universal "Exit" button.

### Menu Structure

The main menu is organized into categories:
- **Reconnaissance**
- **WiFi**
- **Network**
- **Credentials**
- **Remote Access**
- **Exfiltration**
- **Bluetooth**
- **USB**
- **Hardware**
- **Evasion**
- **Games**
- **Utilities**
- **AI**
- And more...

---

## 5. WebUI & Payload IDE

RaspyJack includes a modern web interface accessible at:

- `http://<pi-ip>/`
- `http://<pi-ip>:8080/` (fallback)

### Key Features of the WebUI

- Live system monitor
- Payload browser and launcher
- **Payload IDE** (`/ide`) – edit and run Python payloads directly in the browser
- Loot browser
- Settings (Discord webhook, etc.)
- Terminal access (when enabled)

The WebUI is especially powerful for **headless** operation.

---

## 6. How Payloads Work

Payloads are self-contained Python scripts located in the `payloads/` directory, organized by category.

### Launching Payloads

You can launch payloads in three ways:

1. **From the LCD menu** (when a display is attached)
2. **From the WebUI** (recommended for headless)
3. **From the Payload IDE** (for development/testing)

### Payload Structure

Most payloads follow this pattern:
- Use `get_button()` for input
- Use `ScaledDraw` + `scaled_font()` for display output
- Exit cleanly when **KEY3** is pressed
- Can optionally use the `EXTENSIONS` system for advanced triggering

---

## 7. Payload Categories & Tools

Below is a breakdown of every category with notable tools and usage notes.

### Reconnaissance
- `autoNmapScan.py`, `subnet_mapper.py`, `device_scout.py`, `osint_username.py`, `shodan_query.py`, etc.
- Useful for initial network mapping and target discovery.

### WiFi
- `deauth.py`, `evil_twin.py`, `handshake_hunter.py`, `pmkid_grab.py`, `karma_ap.py`, `beacon_flood.py`
- Strong focus on WiFi reconnaissance and attacks.

### Network
- Many MITM and spoofing tools (`arp_mitm.py`, `dns_hijack.py`, `goodportal.py`, etc.)

### Credentials
- Various credential harvesting and cracking tools.

### Remote Access
- `reverse_shell.py`, `discord_c2.py`, `stealthlink.py`, etc.

### Exfiltration
- Multiple methods to exfiltrate data (`http_exfil.py`, `dns_tunnel.py`, `discord_exfil.py`, etc.)

### Bluetooth
- BLE scanning, spoofing, MITM, audio injection, etc.

### USB
- `usb_ethernet_mitm.py` (USB gadget mode – very useful for direct connection)
- BadUSB / DuckyScript related tools

### Hardware
- GPIO tools, GPS, NFC, LED control, etc.

### Evasion
- MAC randomization, stealth mode, log cleaning, etc.

### Games
- 25+ games (Pac-Man, Tetris, Doom, etc.) – useful for killing time or demonstrating the device.

### Utilities
- Many helper tools (`fast_wifi_connect.py`, `system_monitor.py`, `ragnar.py`, etc.)

### AI
- Object detection, speech-to-text, network anomaly detection, etc.

### SDR
- Software Defined Radio tools (if you have the hardware).

### NFC/RFID
- Reading, cloning, brute-forcing, etc.

---

## 8. Headless Operation on Raspberry Pi 4B (Primary Focus)

This is the most important section for users running RaspyJack on a Pi 4B without an LCD.

### How to Control RaspyJack Headless (Pi 4B)

You have several ways to control the device. You do **not** need to use the replica of the physical interface.

#### Option 1: WebUI Payload Browser (Recommended for most users)

This is the easiest and most practical way:

1. Open the WebUI in your browser (`http://<ip>/` or `http://<ip>:8080`).
2. Go to the **Payloads** section.
3. Browse by category.
4. Click **Start** or **Run** on any payload.

You can start and stop payloads directly from here without simulating button presses. This is usually the fastest method when running headless.

#### Option 2: WebUI Physical Interface Replica (LCD Simulator)

There is a page that replicates the physical LCD + buttons. You can use this if you want the exact same experience as if an LCD was attached. Most people doing serious headless work rarely need this.

#### Option 3: Full Control via SSH (Most Powerful)

You can do almost everything from SSH:

```bash
# View running payload status
cat /dev/shm/rj_payload_state.json

# Start a specific payload manually
python3 /root/Raspyjack/payloads/reconnaissance/autoNmapScan.py

# Stop current payload (sends stop signal)
echo '{"action": "stop"}' > /dev/shm/rj_payload_request.json

# View loot
ls -la /root/Raspyjack/loot/

# Check logs
journalctl -u raspyjack-device.service -f
journalctl -u raspyjack-webui.service -f
```

#### Option 4: Payload IDE

Accessible at `/ide` in the WebUI. This lets you write, edit, save, and run custom payloads directly from the browser. Very useful for field adjustments.

### AI Features Setup and Usage

RaspyJack includes several AI-related payloads in the `ai/` folder:

- **object_detector.py** — Uses computer vision to detect objects via camera.
- **speech_to_text.py** — Converts spoken audio to text.
- **network_anomaly.py** — Detects unusual network behavior.
- **birdnet.py** — Bird sound identification (niche but fun).

**How to use them headless:**
1. Make sure you have the required hardware (USB camera for vision, microphone for speech).
2. Launch them from the WebUI Payloads menu or via SSH.
3. Output (detections, transcriptions, alerts) is usually written to the loot folder or shown in the WebUI.

These are relatively heavy on CPU, so they perform better on a Pi 4B than on a Zero.

### Checking and Managing Loot

Loot is stored in `/root/Raspyjack/loot/`.

**Ways to view loot:**

1. **WebUI Loot Browser** (easiest)
   - Go to the Loot section in the WebUI.
   - Browse folders, preview text files, download captures.

2. **Via SSH**
   ```bash
   ls -la /root/Raspyjack/loot/
   cd /root/Raspyjack/loot/recon/
   cat *.txt
   ```

3. **Direct file access** (if you pull the SD card)

Common loot locations:
- `/loot/recon/` — Scans, Nmap output, device lists
- `/loot/credentials/` — Captured passwords
- `/loot/wifi/` — Handshakes, PMKID files
- `/loot/exfil/` — Data you've pulled

### Recommended Field Combinations (Wardriving / Monitoring)

Here are common useful combinations when running headless on a Pi 4B:

**Basic Wardriving Setup**
- `wifi/handshake_hunter.py` (or `pmkid_grab.py`)
- `reconnaissance/autoNmapScan.py` (periodic)
- `utilities/system_monitor.py` (background)
- Dynamic fan control enabled

**Stealth Monitoring**
- `network/traffic_analyzer.py`
- `ai/network_anomaly.py`
- `evasion/stealth_mode.py`

**Full Remote Access + Data Collection**
- Tailscale enabled
- `remote_access/stealthlink.py` or similar
- Multiple recon payloads on a schedule (using EXTENSIONS or cron)

**Direct Control Mode (no WiFi dependency)**
- Use USB gadget mode (`payloads/usb/usb_ethernet_mitm.py`)
- Connect via USB-C to your phone or laptop
- Access WebUI at 172.20.2.1

These combinations can be started individually from the WebUI. For true automation, advanced users create custom scripts in `EXTENSIONS/` or use the Payload Scheduler if available.

### Why Pi 4B for Headless Use?

- Significantly more CPU and RAM than a Pi Zero → better for running multiple payloads + WebUI simultaneously.
- Better USB controller → more reliable USB gadget mode.
- Easier cooling solutions (critical for 24/7 or high-load use).
- Native Gigabit Ethernet option (if using a USB Ethernet HAT or direct adapter).

### Recommended Headless Architecture (Pi 4B)

**Primary Connection Methods (in order of preference for most users):**

1. **WiFi Client + Tailscale** (Best daily driver)
   - Pi connects to any WiFi hotspot (phone, laptop, travel router, etc.).
   - Tailscale provides stable remote access from anywhere.
   - Use static IP on the local WiFi network for reliability.

2. **USB Direct (Zero Middleman)**
   - When the Pi is physically connected to a host via USB-C (OTG), it can appear as a USB Ethernet device.
   - Pi is reachable at `172.20.2.1`.
   - Excellent when you have physical access or want maximum stealth.

3. **WiFi Client Only (No Tailscale)**
   - Fine for local-only use (same network as your phone/laptop).

### First Boot Headless Setup (Pi 4B)

On a fresh or cloned SD card:

1. Boot the Pi 4B (Ethernet or WiFi).
2. SSH in (default credentials or via your initial network).
3. Run the interactive configuration helper:

   ```bash
   sudo bash /root/Raspyjack/scripts/configure_headless.sh
   ```

   This will ask you for:
   - WiFi SSID + Password (the network the Pi will connect to as a client)
   - Hostname
   - Tailscale (optional but recommended)
   - Fan control (strongly recommended on Pi 4B)

4. Reboot or run the setup script:

   ```bash
   /root/Raspyjack/payloads/utilities/raspyjack_headless_setup.sh
   ```

5. (Recommended) Install the systemd service so everything starts automatically on boot:

   ```bash
   /root/Raspyjack/payloads/utilities/raspyjack_headless_setup.sh install-service
   ```

### Important Pi 4B Specific Considerations

**Cooling & Fan Control**
- The Pi 4B runs hot under sustained load.
- Install a fan + heatsink.
- Use the built-in `dynamic_fan_control.py` payload (controlled via `headless.json`).
- Recommended hardware: IRLZ44N MOSFET on **GPIO 18** (low-side switching).

**Power Supply**
- Use a quality 5V/3A+ power supply.
- Undervoltage can cause WiFi instability and random crashes.

**Static IP (Recommended)**
After the Pi connects to your WiFi network, set a static IP using `nmcli` for reliability:

```bash
sudo nmcli connection modify "YourSSID" ipv4.addresses <YOUR_STATIC_IP>/24
sudo nmcli connection modify "YourSSID" ipv4.gateway <YOUR_GATEWAY_IP>
sudo nmcli connection modify "YourSSID" ipv4.dns "8.8.8.8"
sudo nmcli connection modify "YourSSID" ipv4.method manual
sudo nmcli connection up "YourSSID"
```

**mDNS**
The Pi should be reachable as `raspyjack.local` on the same network (if mDNS is working on your client device).

**Tailscale (Strongly Recommended for Remote Use)**
- Install via the `configure_headless.sh` script or manually.
- Once running, the Pi is reachable from anywhere as `raspyjack.<your-tailnet>.ts.net` or its Tailscale IP.

### Accessing the Pi (Headless Pi 4B)

| Method              | Address Example                          | Requirements                  | Notes |
|---------------------|------------------------------------------|-------------------------------|-------|
| Local WiFi (mDNS)   | http://raspyjack.local/                  | Same network                  | Convenient locally |
| Local WiFi (Static) | http://<YOUR_STATIC_IP>/ or :8080             | Same network + static IP set  | Most reliable local |
| Tailscale           | http://<YOUR_TAILSCALE_IP>/ or Magic DNS        | Tailscale running on client   | Best for remote |
| USB Direct          | http://172.20.2.1/                       | USB-C OTG cable to host       | Zero middleman |

### Running Payloads Headless (Pi 4B)

Since there is no LCD:
- Use the **WebUI** (`http://<ip>/`) to browse and launch payloads.
- Use the **Payload IDE** (`/ide`) to write and test custom payloads.
- Many payloads can also be run directly from the command line if needed.

---

## 9. Advanced Features (Headless Pi 4B Notes)

---

## 9. Advanced Features

### EXTENSIONS System
Located in `EXTENSIONS/`. Allows reusable logic for:
- Waiting for devices to appear/disappear
- Requiring certain capabilities before running
- Chaining payloads

### Ragnar Integration
A powerful separate headless framework accessible via the WebUI or dedicated launcher.

### Payload IDE
Browser-based editor that lets you write, save, and execute custom payloads without touching the SD card.

---

## 10. Tips, Tricks & Best Practices (Headless Pi 4B)

- **Cooling is critical** on a Pi 4B. Use active cooling + the dynamic fan payload for any long-running tasks.
- Use **static IP** on your WiFi network whenever possible for reliability.
- Combine **WiFi Client + Tailscale** for the best remote experience.
- Use **USB Gadget mode** (172.20.2.1) when you have physical access and want maximum independence from WiFi.
- Always keep a copy of your `config/headless.json` backed up somewhere safe (it is gitignored for a reason).
- When running 24/7 or in a bag/vehicle, monitor temperatures via the WebUI.
- For maximum stealth/portability, consider using a small power bank + the USB gadget method instead of relying on a phone hotspot.
- The WebUI + Payload IDE is your primary interface when running headless — learn it well.

---

## Contributing / Custom Payloads

See the template in `payloads/examples/_payload_template.py` and the main README for guidelines.

---

**This guide is a living document.** As RaspyJack evolves, new payloads and features will be added.

For the absolute latest information, also check:
- The official GitHub wiki
- The in-device Payload IDE examples
- The `EXTENSIONS/` system

---

*Last updated: 2026 (based on current codebase)*
## Detailed Payload Catalog (by Category)

### Reconnaissance (~50 payloads)
Tools focused on discovery and information gathering.

**Notable examples:**
- `autoNmapScan.py` — Automated Nmap with common options
- `subnet_mapper.py` — Visual network mapping
- `device_scout.py` — Active device discovery
- `osint_username.py` — Username reconnaissance across platforms
- `shodan_query.py` — Shodan API integration
- `cert_scanner.py`, `service_banner.py`, `passive_os_detect.py`

### WiFi (~19 payloads)
One of the strongest categories.

**Key tools:**
- `deauth.py` — Targeted or broadcast deauthentication
- `evil_twin.py` — Evil Twin with captive portal
- `handshake_hunter.py` — Smart WPA handshake capture
- `pmkid_grab.py` — Offline PMKID attacks
- `karma_ap.py` — Karma attack (responds to all probes)
- `beacon_flood.py`, `ssid_pool.py`, `wifi_probe_dump.py`

### Network (~35 payloads)
MITM, spoofing, and rogue network services.

Includes: ARP spoofing, DNS hijacking, rogue DHCP, CDP/LLDP spoofing, STP attacks, etc.

### Credentials (~12 payloads)
Brute force, sniffing, and relay tools.

Examples: `ssh_bruteforce.py`, `http_cred_sniffer.py`, `ntlm_relay.py`, `pass_the_hash.py`, `kerberoast.py`

### Remote Access (~9 payloads)
C2 and access tools.

- `reverse_shell.py`
- `discord_c2.py`
- `stealthlink.py`
- `reverse_ducky.py`

### Exfiltration (~12 payloads)
Multiple data exfiltration methods.

Supports HTTP, DNS tunneling, SMB, FTP, Discord, Dropbox, USB, BLE, etc.

### Bluetooth (~9 payloads)
BLE and classic Bluetooth tooling.

- Scanning, flooding, MITM, audio injection, DoS

### USB (~6 payloads)
- `usb_ethernet_mitm.py` — Turn Pi into USB Ethernet gadget (highly recommended for direct access)
- BadUSB / DuckyScript tools

### Hardware (~12 payloads)
GPIO, GPS, NFC, sensors, etc.

Includes the dynamic fan control payload.

### Evasion (~6 payloads)
Stealth and anti-analysis tools.

### Games (~31 payloads)
Large collection of games for long deployments or demonstrations.

### Utilities (~75 payloads)
The largest category. Contains many very practical tools:
- `fast_wifi_connect.py`
- `system_monitor.py`
- `ragnar.py` (Ragnar launcher)
- `iface_manager.py`
- Many configuration and helper tools

### AI (~4 payloads)
- Object detection
- Speech-to-text
- Network anomaly detection

### SDR (~9 payloads)
Software Defined Radio tools.

### NFC/RFID (~17 payloads)
Full suite of NFC/RFID tools (reading, cloning, brute forcing, hotel cards, etc.).

---

**Note:** Many payloads have additional options and configurations when launched from the WebUI or Payload IDE.


---

## Payload Field Reference (Quick Jump Guide for Beginners)

This section is designed so you can jump straight to what you need without reading the whole guide.

### I Want To...

**Discover devices on a network**  
→ Start with **Reconnaissance** category. Best first payloads: `autoNmapScan.py`, `subnet_mapper.py`, `device_scout.py`.

**Capture WiFi handshakes or crack WiFi**  
→ Use **WiFi** category. Most common: `handshake_hunter.py`, `pmkid_grab.py`, `deauth.py` (to force handshakes).

**Create a fake WiFi network to steal passwords**  
→ Use `evil_twin.py` (in WiFi category). It creates a fake access point with a captive portal.

**Kick people off WiFi**  
→ Use `deauth.py`.

**Get remote access / a shell on something**  
→ Look in **Remote Access** category. Common starting points: `reverse_shell.py` or Discord-based C2 tools.

**Steal data from a network**  
→ Use tools in **Exfiltration**. Many options depending on what access you have (HTTP, DNS tunnel, Discord, SMB, etc.).

**Attack Bluetooth devices**  
→ **Bluetooth** category. Good starting points: `ble_scanner.py` then `ble_mitm.py` or `bt_audio_inject.py`.

**Connect to the Pi directly with a cable (no WiFi)**  
→ Use `usb/usb_ethernet_mitm.py`. This turns the Pi into a USB Ethernet gadget. Connect via USB-C and go to `http://172.20.2.1/`.

**Control a fan based on temperature**  
→ Use `hardware/dynamic_fan_control.py`. Configure it in `headless.json`. Recommended hardware: IRLZ44N MOSFET on GPIO 18.

**Run multiple things at once**  
Most payloads can run alongside each other. Common safe combinations for field work:
- Handshake hunter + system monitor + fan control
- Network anomaly detection + traffic analyzer
- Multiple reconnaissance scans on a schedule

**Check what data the Pi has collected (Loot)**  
- Best way: Open the WebUI → Loot browser.
- Via SSH: `ls -la /root/Raspyjack/loot/`
- Important folders: `recon/`, `credentials/`, `wifi/`

**Use the AI features**  
Look in the **AI** category:
- `object_detector.py` (needs camera)
- `speech_to_text.py` (needs microphone)
- `network_anomaly.py`

These are heavier. Best on Pi 4B.

### How to Actually Run Things Headless (Pi 4B)

You have two main interfaces:

1. **WebUI Payload List** (easiest)
   - Go to the payloads section.
   - Click Start/Stop on individual payloads.
   - You do **not** need to use the fake LCD interface for normal use.

2. **WebUI Fake LCD Interface** (only if you want the exact button experience)
   - There is a replica of the physical screen + buttons.
   - Most people doing serious headless work rarely use this.

**Full control via SSH is also possible** (see earlier section in this guide).

---

**End of expanded field reference section.**

---

## Wardriving on Headless Pi 4B (GPS Without Buying Hardware)

This is one of the most common advanced use cases for a headless RaspyJack Pi 4B.

### What Wardriving Actually Does in RaspyJack

The main wardriving payload (`reconnaissance/wardriving.py`) does the following:

- Puts compatible USB WiFi adapters into **monitor mode**.
- Passively (and actively) discovers nearby WiFi networks (BSSIDs, SSIDs, security type, signal strength, channels, etc.).
- Records them with timestamps.
- When GPS data is available, it tags every network with latitude/longitude.
- Continuously saves data and can export in Wigle-compatible CSV format (the most popular wardriving database).

It is designed for driving/walking around while logging networks + location.

### The GPS Problem (and Solutions)

RaspyJack's wardriving payload expects GPS data. By default it looks for a hardware GPS module via `gpsd`.

Most people doing portable wardriving do **not** want to buy a separate GPS module.

Here are the realistic options, ranked for your exact use case (Pi 4B in a bag, phone providing the hotspot):

### Best Option: Phone Provides Both Hotspot + GPS (Recommended)

**Architecture:**
- Your phone creates the <YOUR_HOTSPOT_SSID> hotspot.
- The Pi connects to the phone as a normal WiFi client.
- The **same phone** provides GPS data to the Pi over the local network (no internet required).

**How to do it:**

1. On the Pi, start the `mobile_gps` payload (either from WebUI or SSH):
   ```bash
   python3 /root/Raspyjack/payloads/hardware/mobile_gps.py
   ```

2. On your phone (while connected to the Pi's network or the same hotspot), open a browser and go to:
   ```
   http://raspyjack.local:4443
   ```
   or
   ```
   http://<YOUR_STATIC_IP>:4443   (use the Pi's IP on the hotspot)
   ```

3. The page will ask for location permission. Allow it (use high accuracy).

4. The phone will now continuously send its GPS coordinates to the Pi over the local WiFi.

5. Start the wardriving payload. It should pick up the GPS data being fed from the phone.

**Advantages:**
- Only one device needed for both internet/hotspot and GPS.
- No extra hardware.
- Works very well in practice.

**Downsides:**
- Your phone is doing double duty (hotspot + GPS sharing), so battery drain is higher.
- The phone must keep the browser page open.

### Good Alternative: Laptop as Hotspot + Phone as GPS Source

**Architecture:**
- Laptop creates a hotspot.
- Pi connects to the laptop's hotspot.
- Phone (connected to the laptop's hotspot or via USB) sends GPS data to the Pi.

This can be cleaner if you want the phone dedicated to GPS only.

**How to implement GPS sharing from phone:**
- Use the same `mobile_gps.py` method above (phone opens the Pi's web page).
- Or use Android apps like:
  - **"GPS Share"** or **"Share GPS"** (various apps on Play Store / F-Droid)
  - Termux + a small Python/HTTP script that broadcasts location.

### Other GPS Sharing Methods

- **USB Tethering + GPS forwarding**: More complicated on Android (requires apps like "GPS over USB" or custom scripts). Usually not worth it compared to the browser method.
- **Termux on Android**: You can write a small script that uses `termux-location` and posts coordinates to the Pi via HTTP. Very flexible.

### Important Notes for Pi 4B Wardriving

- The built-in WiFi on the Pi 4B is generally **not good** for monitor mode wardriving.
- You will almost certainly need one or more external USB WiFi adapters that support monitor mode (common good chipsets: RTL8812AU, RTL8814AU, RTL88x2BU, etc.).
- Make sure those adapters are properly supported in the version of Raspberry Pi OS you're running.

### Recommended Practical Setup (Most People Doing This)

1. Phone creates hotspot (<YOUR_HOTSPOT_SSID>).
2. Pi connects as client + gets static IP.
3. Phone runs the browser page from `mobile_gps.py` to feed GPS.
4. Pi runs `wardriving.py` (or a custom lighter version) in the background.
5. Tailscale enabled for remote monitoring if desired.
6. Fan control active because the Pi will be under load with monitor mode adapters.

This setup requires **zero extra GPS hardware** and works surprisingly well.

