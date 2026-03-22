# ADB Wireless Self-Connect on Android

Connect your phone to itself over ADB. No computer. No USB cable. One device — and it unlocks most of what SELinux blocks from Termux.

---

## What This Is

Termux cannot call Android system binaries directly. SELinux blocks them:

```
/system/bin/screencap   → Operation not permitted
/system/bin/settings    → Operation not permitted
/system/bin/pm          → Operation not permitted
/system/bin/dumpsys     → Operation not permitted
```

ADB wireless debugging bypasses this. The phone connects to itself via `127.0.0.1`, and `adb shell` runs as the `shell` user, which Android grants access to these binaries. The Termux session calls `adb`, which talks to the ADB daemon running on the same device.

**Requires:** WiFi (Android checks for a WiFi association, not internet access). Does not require root.

> ADB wireless self-connect has been verified on Samsung Galaxy S26 Ultra (Android 16). The pairing workflow should work on any device with Developer Options and wireless debugging support, but results may vary. Device-specific results welcome via the device_report issue template.

---

## Before and After

| Capability | Termux (no ADB) | With ADB |
|------------|-----------------|----------|
| Screenshot | Blocked | `adb shell screencap` |
| System settings (brightness, DND) | Blocked | `adb shell settings get/put` |
| Calendar events | Blocked | `adb shell content query` |
| Installed apps list | Blocked | `adb shell pm list packages` |
| Full battery details | Blocked | `adb shell dumpsys battery` |
| Touch/key injection | Blocked | `adb shell input tap/swipe/text` |
| Full process list | Blocked | `adb shell ps -A` |
| Activity manager | Partial | `adb shell am start/force-stop` (full) |
| Device properties | Blocked | `adb shell getprop` |
| Battery % (basic) | `termux-battery-status` | Both work |
| Camera capture | `termux-camera-photo` | Both work |
| TTS | `termux-tts-speak` | Both work |
| Clipboard | `termux-clipboard-get/set` | Both work |
| GPS location | `termux-location` | Both work |
| SMS | `termux-sms-list/send` | Both work |
| Notifications | `termux-notification-list` | Both work |
| Background scheduling | `crond` / job-scheduler | Both work |
| Volume control | `termux-volume` | Both work |
| Vibration | `termux-vibrate` | Both work |
| Wifi info | `termux-wifi-connectioninfo` | Both work |
| Sensors | `termux-sensor` | Both work |

The bottom 13 rows work without ADB via Termux API. The top 8 require ADB.

---

## Setup

### Prerequisites

Install `android-tools` in Termux:

```sh
pkg install android-tools
```

### Step 1 — Enable developer options

Go to **Settings → About phone → Software information**, tap **Build number** 7 times. Developer options is now unlocked.

### Step 2 — Enable wireless debugging

Go to **Settings → Developer options → Wireless debugging** and toggle it on. You'll see a confirmation dialog — accept it.

### Step 3 — Open the pairing dialog

Inside Wireless debugging, tap **Pair device with pairing code**. A dialog appears with:
- A 6-digit pairing code
- A pairing port (labeled something like "Wi-Fi pairing code port: 41823")

The pairing port and connection port are different numbers. Note both.

**The dialog closes if you switch away from Settings.** To work around this:

1. Take a screenshot of the dialog before switching apps (use your phone's screenshot gesture — volume down + power, or the status bar shortcut).
2. Switch to Termux.
3. Open your Gallery or Files app in split-screen, or just remember the numbers.

Alternatively: keep Settings open in the background and use split-screen or pop-up view if your device supports it.

### Step 4 — Pair

In Termux, run:

```sh
adb pair 127.0.0.1:<pairing-port> <code>
```

Example:
```sh
adb pair 127.0.0.1:41823 123456
```

Expected output:
```
Successfully paired to 127.0.0.1:41823
```

**If you get `error: protocol fault (couldn't read status message): Success`:** This is a known bug in ADB 35.x. Run the same command again. It usually succeeds on the second attempt.

### Step 5 — Connect

After pairing, tap back in the Wireless debugging screen to see the main port (labeled "IP address & Port"). This is a different port from the pairing port.

```sh
adb connect 127.0.0.1:<connection-port>
```

Example:
```sh
adb connect 127.0.0.1:42103
```

Expected output:
```
connected to 127.0.0.1:42103
```

Verify it's working:

```sh
adb shell getprop ro.build.version.release
```

This should return your Android version number.

---

## After Connecting

### Take a screenshot

```sh
adb shell screencap /sdcard/screen.png
adb pull /sdcard/screen.png ~/screen.png
```

### Read system settings

```sh
# Get current brightness
adb shell settings get system screen_brightness

# Get DND mode
adb shell settings get global zen_mode

# Set brightness (0–255)
adb shell settings put system screen_brightness 128
```

### Query calendar

```sh
adb shell content query --uri content://com.android.calendar/events \
  --projection title,dtstart,dtend,description \
  --where "dtstart > $(date +%s%3N)"
```

### List installed apps

```sh
adb shell pm list packages
# Third-party only:
adb shell pm list packages -3
```

### Inject input

```sh
# Tap at coordinates
adb shell input tap 540 1200

# Type text
adb shell input text "hello"

# Swipe up (unlock gesture)
adb shell input swipe 540 1800 540 900 300
```

---

## Connection Persistence

The ADB connection drops on screen lock, app switch, and reboot. The pairing, however, persists — you only pair once. After a reboot:

1. Re-enable Wireless debugging (it toggles off on reboot on some devices).
2. Note the new connection port (it changes on each enable).
3. Run `adb connect 127.0.0.1:<new-port>`.

To automate reconnection, check the current port programmatically:

```sh
# This gets the connection port from the device (requires ADB already connected, or manual check)
adb shell settings get global adb_wifi_port
```

A boot script can attempt to reconnect, but the port is only stable within a session. If your automation needs ADB, check the connection at the start of each run.

---

## Without WiFi

ADB wireless debugging requires WiFi association. Android checks whether the wifi radio is connected to an access point — not whether the internet is reachable. A router with no internet connection works.

**What works without WiFi (Termux API, no ADB required):**

- Battery status — `termux-battery-status`
- Camera capture — `termux-camera-photo`
- TTS — `termux-tts-speak`
- Clipboard — `termux-clipboard-get` / `termux-clipboard-set`
- GPS location — `termux-location`
- SMS (read/send) — `termux-sms-list` / `termux-sms-send`
- Notifications — `termux-notification-list`
- Background scheduling — `crond` or `termux-job-scheduler`
- Volume — `termux-volume`
- Vibration — `termux-vibrate`
- WiFi info — `termux-wifi-connectioninfo`
- Sensors — `termux-sensor`

**Approaches for ADB without a router:**

1. **Phone hotspot** — enable your phone's mobile hotspot. The AP interface typically gets a static IP (often `192.168.43.1`). `adbd` binds to all interfaces. After enabling hotspot, pair and connect using that IP rather than `127.0.0.1`. Untested across all devices — your AP interface IP may differ.

2. **Session persistence after WiFi drop** — some users report that an established ADB connection survives a WiFi drop in the same session (the radio goes down but the TCP connection stays alive briefly). Not reliable across reboots or long gaps.

3. **`adb tcpip` mode** — if you have a computer nearby, you can set `adb tcpip 5555` once over USB, then disconnect and connect wirelessly on port 5555. Doesn't help in a WiFi-free scenario, but keeps the connection available without re-pairing each session.

---

## Security

### What the attack surface looks like

Wireless debugging enabled means your device is listening for ADB connections on a WiFi-routable port. Anyone on the same WiFi network can attempt to pair.

**Mitigations Android provides:**
- Pairing requires a code displayed on-screen. Remote attackers cannot see your screen.
- Each pairing is explicit — you approve it by opening the pairing dialog.
- The connection is tied to the paired key. Without pairing first, a connection attempt fails.

**What to watch for:**
- Public WiFi networks (cafes, hotels, airports) — disable Wireless debugging when you're on networks you don't control. Anyone on the same subnet could attempt to pair.
- Shared home networks with untrusted devices — same consideration.
- The connection port changes on each session, which slightly reduces attack surface, but determined local network attackers can scan for it.

### Practical security posture

For personal use on a home network: acceptable risk. The pairing code requirement means passive attack is not possible.

For public WiFi: disable Wireless debugging. Re-enable when you're back on a trusted network.

### What ADB shell can access

`adb shell` runs as Android's `shell` user. This is more privileged than Termux's app sandbox but less privileged than root. It can read most of the filesystem, inject input, query system settings, and access content providers. It cannot install system-signed packages, modify `/system/`, or bypass the keystore.

---

## Troubleshooting

**`adb: command not found`**
```sh
pkg install android-tools
```

**`error: protocol fault (couldn't read status message): Success`**
Run the `adb pair` command again. Known bug in ADB 35.x, usually resolves on retry.

**`failed to connect to 127.0.0.1:<port>: Connection refused`**
Wireless debugging may have toggled off (happens on some devices after screen lock). Go back to Developer options, toggle it back on, get the new port, reconnect.

**Pairing dialog dismissed before you got the port**
Open the dialog again — a new code and port will be generated. The old pairing (if you had one) is not affected.

**`adb shell screencap` returns empty or corrupted file**
Some devices need the path specified differently:
```sh
adb shell screencap -p /sdcard/screen.png
```

**Connection drops frequently**
Android may be toggling WiFi sleep. Go to **Developer options → WiFi scan throttling** (disable) and ensure the screen-off WiFi setting does not put the radio to sleep.

---

## Summary

ADB wireless self-connect gives Termux-based tools access to Android system APIs that SELinux blocks from the Termux app sandbox. Setup takes about 5 minutes. Once paired, reconnecting is a single command. The 12 Termux API features continue to work regardless of ADB state — ADB adds on top of them, it doesn't replace them.
