# ADB Wireless Self-Connect on Android

Connect your phone to itself over ADB (Android Debug Bridge, the standard tool for sending commands to an Android device). No computer. No USB cable. One device, and it unlocks most of what SELinux (Android's mandatory access-control layer, which stops apps from running system commands) blocks from Termux.

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

> This is the standard Android wireless-debugging pairing workflow. It should work on any device with Developer Options and wireless debugging support, though results vary by device and Android version.

---

## Before and After

### Capabilities that require ADB

| Capability | Termux (no ADB) | With ADB | Risk/Exposure |
|------------|-----------------|----------|---------------|
| Screenshot | Blocked | `adb shell screencap` | Captures any screen including banking apps |
| System settings (brightness, DND) | Blocked | `adb shell settings get/put` | Can modify device configuration |
| Calendar events | Blocked | `adb shell content query` | Reads private calendar data |
| Installed apps list | Blocked | `adb shell pm list packages` | Full app inventory visible |
| Full battery details | Blocked | `adb shell dumpsys battery` | Device state information |
| Touch/key injection | Blocked | `adb shell input tap/swipe/text` | Can operate any app autonomously |
| Full process list | Termux processes only | `adb shell ps -A` (all system processes) | All running processes visible |
| Activity manager | Partial | `adb shell am start/force-stop` (full) | Can launch or kill any app |
| Device properties | Blocked | `adb shell getprop` | Hardware and build identifiers |

### Capabilities that work without ADB (Termux API)

| Capability | Termux (no ADB) | With ADB |
|------------|-----------------|----------|
| Battery % (basic) | `termux-battery-status` | Both work |
| Camera capture | `termux-camera-photo` | Both work |
| TTS | `termux-tts-speak` | Both work |
| Clipboard | `termux-clipboard-get/set` | Both work |
| GPS location | `termux-location` | Both work |
| SMS | `termux-sms-list/send` | Both work |
| Notifications | `termux-notification-list` | Both work |
| Background scheduling | `crond` (a background task scheduler) / job-scheduler | Both work |
| Volume control | `termux-volume` | Both work |
| Vibration | `termux-vibrate` | Both work |
| Wifi info | `termux-wifi-connectioninfo` | Both work |
| Sensors | `termux-sensor` | Both work |

The first group needs ADB. The second group works through the Termux API without ADB.

> **Note:** The Termux API rows require the **Termux:API companion app** installed from the same source as Termux (both from F-Droid, the open-source Android app store, or both from GitHub). Mixing sources causes signature mismatches and silent failures.

---

## Setup

### Prerequisites

Install `android-tools` in Termux:

```sh
pkg install android-tools
```

### Step 1: Enable developer options

Go to **Settings → About phone → Software information**, tap **Build number** 7 times. Developer options is now unlocked.

### Step 2: Enable wireless debugging

Go to **Settings → Developer options → Wireless debugging** and toggle it on. You'll see a confirmation dialog. Accept it.

### Step 3: Open the pairing dialog

Inside Wireless debugging, tap **Pair device with pairing code**. A dialog appears with:
- A 6-digit pairing code
- A pairing port (labeled something like "Wi-Fi pairing code port: 37000")

This pairing port is used only to pair. A separate connection port, shown later in Step 5, is what you connect to afterward. For now, note the pairing code and the pairing port.

**The dialog closes if you switch away from Settings.** To work around this:

1. Take a screenshot of the dialog before switching apps (use your phone's screenshot gesture: volume down + power, or the status bar shortcut).
2. Switch to Termux.
3. Open your Gallery or Files app in split-screen, or just remember the numbers.

Alternatively: keep Settings open in the background and use split-screen or pop-up view if your device supports it.

### Step 4: Pair

In Termux, run:

```sh
adb pair 127.0.0.1:<pairing-port> <code>
```

Example:
```sh
adb pair 127.0.0.1:37000 123456
```

Expected output:
```
Successfully paired to 127.0.0.1:37000
```

**If you get `error: protocol fault (couldn't read status message): Success`:** This is a known bug in ADB 35.x. Run the same command again. It usually succeeds on the second attempt.

### Step 5: Connect

After pairing, tap back in the Wireless debugging screen to see the main port (labeled "IP address & Port"). This is a different port from the pairing port.

```sh
adb connect 127.0.0.1:<connection-port>
```

Example:
```sh
adb connect 127.0.0.1:38000
```

Expected output:
```
connected to 127.0.0.1:38000
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
NOW=$(date +%s%3N)
adb shell content query --uri content://com.android.calendar/events \
  --projection title:dtstart:dtend:description \
  --where "dtstart\>$NOW"
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

The ADB connection drops on screen lock, app switch, and reboot. The pairing, however, persists; you only pair once. After a reboot:

1. Re-enable Wireless debugging (it toggles off on reboot on some devices).
2. Note the new connection port (it changes on each enable).
3. Run `adb connect 127.0.0.1:<new-port>`.

There is a catch when you try to automate this. Reading the port with `adb shell` requires ADB to already be connected, so it cannot bootstrap the first connection of a session. After a reboot you still read the new port from the Wireless debugging screen by hand. Once you are connected, this command confirms the active port:

```sh
adb shell settings get global adb_wifi_port
```

The port is only stable within a session. If your automation needs ADB, check the connection at the start of each run.

---

## Without WiFi

ADB wireless debugging requires WiFi association. Android checks whether the wifi radio is connected to an access point, not whether the internet is reachable. A router with no internet connection works.

**What works without WiFi (Termux API, no ADB required):** all the Termux API capabilities listed in the "Capabilities that work without ADB" table above. None of them need a network connection.

**Approaches for ADB without a router:**

1. **Phone hotspot:** enable your phone's mobile hotspot. The AP interface typically gets a static IP (often `192.168.43.1`). `adbd` (the on-device ADB daemon) binds to all interfaces. After enabling hotspot, pair and connect using that IP rather than `127.0.0.1`. Untested across all devices; your AP interface IP may differ.

2. **Session persistence after WiFi drop:** some users report that an established ADB connection survives a WiFi drop in the same session (the radio goes down but the TCP connection stays alive briefly). Not reliable across reboots or long gaps.

---

## Security

### What the attack surface looks like

Wireless debugging enabled means your device is listening for ADB connections on a WiFi-routable port. Anyone on the same WiFi network can attempt to pair.

**Mitigations Android provides:**
- Pairing requires a code displayed on-screen. Remote attackers cannot see your screen.
- Each pairing is explicit; you approve it by opening the pairing dialog.
- The connection is tied to the paired key. Without pairing first, a connection attempt fails.

**What to watch for:**
- Public WiFi networks (cafes, hotels, airports): disable Wireless debugging when you're on networks you don't control. Anyone on the same subnet could attempt to pair.
- Shared home networks with untrusted devices: same consideration.
- The connection port changes on each session, which slightly reduces attack surface, but determined local network attackers can scan for it.

### Practical security posture

For personal use on a home network: acceptable risk, in my own judgment, not a guarantee. The pairing-code requirement blocks pairing by an attacker who cannot see your screen.

For public WiFi: disable Wireless debugging. Re-enable when you're back on a trusted network.

### What ADB shell can access

`adb shell` runs as Android's `shell` user. This is more privileged than Termux's app sandbox but less privileged than root. It can read most of the filesystem, inject input, query system settings, and access content providers (the Android interface apps use to share structured data such as calendar entries and contacts). On a stock, non-rooted device it cannot install system-signed packages, modify `/system/`, or bypass the keystore.

---

## When to use ADB vs Termux:API

These are different access mechanisms with different security postures. Pick the lighter-weight one when it's enough.

| You want to... | Use | Why |
|---|---|---|
| Battery status, notifications, clipboard, vibration, TTS, GPS, camera | **Termux:API** | App-level permission, per-permission grants, no network-accessible port |
| Read SMS or contacts | **Termux:API** (with explicit Android permission grant) | ADB also works but requires the wireless port to be open |
| Take a screenshot of any app | **ADB** | Termux can't screencap outside its own UI |
| Inject touch/swipe/text into other apps | **ADB** | Termux can't input outside its own UI |
| Query `dumpsys`, full process list, system settings | **ADB** | Termux's app sandbox blocks these |
| Read system logs (logcat) | **ADB** | Same reason |
| Read calendar events | **ADB** content-provider query (Termux:API does not expose calendar) | n/a |
| Run cron-style automation without UI access | Either, neither requires UI | n/a |

If you only need the Termux:API category, do not enable wireless debugging. The pairing-code requirement provides reasonable protection on trusted networks, but the simplest security posture is "the port is closed." Pair only when you actually need the ADB-only capabilities.

If you need both: enable ADB only while you're actively using its capabilities, then toggle it off in Developer Options.

---

## Troubleshooting

**`adb: command not found`**
```sh
pkg install android-tools
```

**`error: protocol fault (couldn't read status message): Success`**
Run the `adb pair` command again. Known bug in ADB 35.x (reports as version 1.0.41 in `adb version` output), usually resolves on retry.

**`failed to connect to 127.0.0.1:<port>: Connection refused`**
Wireless debugging may have toggled off (happens on some devices after screen lock). Go back to Developer options, toggle it back on, get the new port, reconnect.

**Pairing dialog dismissed before you got the port**
Open the dialog again. A new code and port will be generated. The old pairing (if you had one) is not affected.

**`adb shell screencap` returns empty or corrupted file**
Some devices need the path specified differently:
```sh
adb shell screencap -p /sdcard/screen.png
```

**Connection drops frequently**
Android may be toggling WiFi sleep. Go to **Developer options → WiFi scan throttling** (disable) and ensure the screen-off WiFi setting does not put the radio to sleep.

---

## Summary

ADB wireless self-connect gives Termux-based tools access to Android system APIs that SELinux blocks from the Termux app sandbox. Setup takes about 5 minutes. Once paired, reconnecting is a single command. The 12 Termux API features continue to work regardless of ADB state; ADB adds on top of them, it doesn't replace them.

---

*Last updated: 2026-07-01.*
