"""
RaspyJACKED — Management interface guard
-----------------------------------------
Returns the interface that handles WebUI / hotspot connectivity so that
payloads know NOT to put it into monitor mode or perform channel-hopping scans.

Priority (highest first):
  1. RJ_MGMT_IFACE env var (explicit override)
  2. wifi.interface value in config/headless.json (or the detected iface if "auto")
  3. First interface that has an active connection via nmcli
  4. "wlan0" as a safe fallback

Callers:
    from payloads._mgmt_iface import get_mgmt_iface

    MGMT_IFACE = get_mgmt_iface()   # call once at module load
    if iface == MGMT_IFACE:
        skip / warn / choose another adapter
"""

import json
import os
import subprocess

_HEADLESS_CONFIG = "/root/Raspyjack/config/headless.json"
_cache: str | None = None


def _detect_auto_iface() -> str | None:
    """Mirror the logic in raspyjack_headless_setup.sh detect_wifi_interface()."""
    usb_iface = None
    onboard_iface = None
    try:
        for name in sorted(os.listdir("/sys/class/net")):
            if not name.startswith("wlan"):
                continue
            devpath = ""
            try:
                devpath = os.path.realpath(f"/sys/class/net/{name}/device")
            except Exception:
                pass
            if "usb" in devpath:
                if usb_iface is None:
                    usb_iface = name
            elif "mmc" in devpath or "platform" in devpath:
                if onboard_iface is None:
                    onboard_iface = name
    except Exception:
        pass
    return usb_iface or onboard_iface


def _active_nmcli_iface() -> str | None:
    """Return the first connected WiFi interface reported by nmcli."""
    try:
        r = subprocess.run(
            ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "dev", "status"],
            capture_output=True, text=True, timeout=5,
        )
        for line in r.stdout.splitlines():
            parts = line.split(":")
            if len(parts) >= 3 and "wifi" in parts[1] and "connected" in parts[2]:
                return parts[0]
    except Exception:
        pass
    return None


def get_mgmt_iface() -> str:
    """Return the name of the management (WebUI) interface. Cached after first call."""
    global _cache
    if _cache is not None:
        return _cache

    # 1. Explicit env override
    env_val = os.environ.get("RJ_MGMT_IFACE", "").strip()
    if env_val:
        _cache = env_val
        return _cache

    # 2. headless.json
    try:
        with open(_HEADLESS_CONFIG) as f:
            cfg = json.load(f)
        pref = cfg.get("wifi", {}).get("interface", "auto")
        if pref and pref != "auto":
            _cache = pref
            return _cache
        # "auto" — run the same detection logic as the shell script
        detected = _detect_auto_iface()
        if detected:
            _cache = detected
            return _cache
    except Exception:
        pass

    # 3. Ask nmcli
    nmcli_iface = _active_nmcli_iface()
    if nmcli_iface:
        _cache = nmcli_iface
        return _cache

    # 4. Safe fallback
    _cache = "wlan0"
    return _cache


def is_mgmt_iface(iface: str) -> bool:
    """Return True if *iface* is the management interface that must not be disrupted."""
    return iface == get_mgmt_iface()
