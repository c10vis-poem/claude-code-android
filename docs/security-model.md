# Security Model -- Claude Code on Android

This document describes what Termux:API permissions and ADB wireless debugging expose when used with Claude Code on Android. It is written for anyone considering granting these capabilities -- developer or not. Read this before enabling Termux:API permissions or ADB wireless debugging.

---

## What Termux:API Permissions Expose

When you grant a permission to the Termux:API companion app, every process running inside Termux can access that data type. There is no per-session or per-tool scoping -- once a permission is granted, it stays granted for all Termux processes until you revoke it in Android Settings.

| Data Type | Command | Permission Gate | What This Means |
|-----------|---------|-----------------|-----------------|
| SMS (read and send) | `termux-sms-list`, `termux-sms-send` | SMS permission | Any Termux process can read your text messages and send new ones |
| Contacts | `termux-contact-list` | Contacts permission | Full contact list accessible from Termux |
| Call log | `termux-call-log` | Call log permission | Incoming and outgoing call history readable |
| GPS location | `termux-location` | Location permission | Real-time device coordinates available |
| Camera | `termux-camera-photo` | Camera permission | Can take photos without the camera app open |
| Microphone | `termux-microphone-record` | Microphone permission | Can record audio in the background |
| Clipboard | `termux-clipboard-get`, `termux-clipboard-set` | None (pre-Android 13) | Clipboard contents readable and writable without permission on older Android versions |
| Notifications | `termux-notification-list` | Notification access | Can read notification content from all apps |
| Sensors | `termux-sensor` | None | Accelerometer, gyroscope, barometer, magnetometer, and other hardware sensors accessible |
| Fingerprint | `termux-fingerprint` | Biometrics | Triggers the biometric prompt (does not read fingerprint data) |
| Phone dialing | `termux-telephony-call` | Phone permission | Can initiate outgoing calls |
| Text-to-speech | `termux-tts-speak` | None | Can speak text aloud through the device speaker |

---

## What ADB Adds

ADB wireless debugging runs commands as Android's `shell` user -- a system-level debug identity that is more privileged than any app. These capabilities do not require any Termux:API permissions.

| Capability | Command | Impact |
|-----------|---------|--------|
| Screenshot any app | `adb shell screencap` | Captures whatever is on screen, including banking apps, password managers, and private conversations |
| Screen recording | `adb shell screenrecord` | Continuous video capture of the display |
| Touch and key injection | `adb shell input tap/swipe/text` | Can tap buttons, type text, and navigate any app autonomously |
| Launch or stop any app | `adb shell am start/force-stop` | Can open banking apps, authenticators, email, or any installed application |
| SMS via content provider | `adb shell content query --uri content://sms` | Reads SMS messages through a different access path than Termux:API |
| Contacts via content provider | `adb shell content query --uri content://contacts` | Reads contacts through a different access path than Termux:API |
| System settings | `adb shell settings get/put` | Can read and modify device configuration (brightness, DND, etc.) |
| Full process list | `adb shell ps -A` | Lists every running process on the device |
| System logs | `adb logcat` | May contain authentication tokens, URLs, and debug data from other apps |
| Installed apps | `adb shell pm list packages` | Complete list of every app installed on the device |
| Hardware sensors | `adb shell dumpsys sensorservice` | Full hardware sensor inventory (42 sensor types observed in our testing) |
| Device properties | `adb shell getprop` | Hardware identifiers, build info, carrier info |

---

## ADB Bypasses Termux:API Permission Denials

This is the critical point most users miss. If you deny SMS permission to the Termux:API companion app, `termux-sms-list` correctly fails. But `adb shell content query --uri content://sms` still works -- because ADB operates as the `shell` user, not as the Termux app. Android's per-app permission model does not apply to ADB commands. Denying a permission in Android Settings blocks the app-level path but leaves the ADB path open. These are two completely different access levels using two different privilege models.

---

## Threat Scenarios

**Can the agent read my text messages?**
Yes, if you granted SMS permission to Termux:API (`termux-sms-list`) or if ADB is connected (`adb shell content query --uri content://sms`). This includes 2FA codes delivered via SMS.

**Can it screenshot my banking app?**
Only with ADB connected. `adb shell screencap` captures whatever is currently on screen. If a banking app is in the foreground, the screenshot includes it.

**Can it operate my phone autonomously?**
With ADB connected, yes. `adb shell am start` opens any app, and `adb shell input tap/swipe/text` navigates it. Combined, these can open an app, tap buttons, enter text, and interact with the UI without the user touching the screen.

**Can it send data to an external server?**
By default, Claude Code has access to `curl`, `wget`, and other network tools through the Bash tool. The SSRF guard (if installed) blocks WebFetch requests to internal IPs, but does not intercept Bash-level network commands. There is no outbound data boundary by default.

**Can a malicious MCP server access my data?**
MCP servers receive tool responses from Claude Code. If Claude Code has access to contacts, SMS, or location data, that data can appear in tool responses sent to any connected MCP server. The SSRF guard does not intercept MCP data flow.

**Can a malicious file trick the agent into exfiltrating data?**
Prompt injection -- where a file contains instructions that redirect the agent's behavior -- is a known risk with all LLM-based tools. The risk is non-zero. A file could attempt to instruct the agent to send data to an external URL.

---

## Existing Mitigations

| Mitigation | What It Covers | What It Does Not Cover |
|-----------|---------------|----------------------|
| **SSRF guard** ([docs](ssrf-guard.md)) | Blocks WebFetch requests to private/reserved IP ranges and non-HTTP schemes | Does not block Bash-level `curl`/`wget`, does not intercept MCP data flow, does not prevent DNS rebinding |
| **Fingerprint gate** ([docs](fingerprint-gate.md)) | Requires biometric approval before sensitive operations (git push, destructive commands by default) | Only gates operations you configure it for -- does not block Termux:API or ADB commands by default |
| **CLAUDE.md constitution** ([template](constitution-template.md)) | Defines behavioral rules the model follows -- scope boundaries, forbidden actions, confirmation requirements | Model-enforced, not technically enforced. The model can be instructed to ignore it via prompt injection |
| **Claude's safety training** | Anthropic's RLHF training makes the model resist harmful instructions | Not a technical control. Effective in most cases but not absolute |
| **Agent permissions matrix** ([docs](agent-permissions.md)) | Documents the principle that no agent should hold both web access and write access | Advisory framework, not a runtime enforcement mechanism |

---

## What's Not Covered

These gaps exist by default in the current setup:

- **No Termux:API command restriction.** Once a permission is granted, every Termux process can use it. There is no way to allow Claude Code to use the camera but deny it SMS access at the Termux level -- this must be done in Android's permission settings for the Termux:API app.
- **No ADB command restriction.** Once ADB is connected, the full set of `adb shell` commands is available. There is no built-in way to allow screencap but deny input injection.
- **No outbound data exfiltration boundary.** Claude Code can run `curl`, `wget`, or any network command via the Bash tool. There is no default firewall or egress filter preventing data from being sent to external servers.
- **No MCP data boundary.** Data flowing to MCP servers is not filtered or restricted. Any data Claude Code can access may appear in MCP tool responses.
- **No session-level tool scoping for interactive use.** The `--tools` and `--disallowedTools` flags work for headless (`claude -p`) sessions, but interactive sessions do not currently support runtime tool restriction beyond hooks.

---

## Recommended Setup for Minimal Risk

1. **Start without ADB.** Path A and Path B work fully without ADB wireless debugging. Only enable ADB when you specifically need screenshot, input injection, or system query capabilities.
2. **Deny unnecessary Termux:API permissions.** Go to Android Settings and deny SMS, Contacts, Call Log, Camera, Microphone, and Location for the Termux:API app unless your workflow requires them. Claude Code works normally without any of these.
3. **Install the SSRF guard.** It blocks the most common SSRF vector (WebFetch to internal IPs). See [SSRF Guard](ssrf-guard.md).
4. **Install the fingerprint gate.** Configure it to require biometric approval for operations you consider sensitive. See [Fingerprint Gate](fingerprint-gate.md).
5. **Extend the fingerprint gate** to cover Termux:API commands (`termux-sms-*`, `termux-contact-*`, `termux-location`, `termux-camera-*`) and ADB commands (`adb shell`) if you use them.
6. **Write a CLAUDE.md constitution.** Define explicit rules for what the agent may and may not do. See the [Constitution Template](constitution-template.md).
7. **Sandbox headless sessions.** If you run `claude -p` from cron or scripts, use `--tools` and `--disallowedTools` to restrict available capabilities. See the [install guide](install.md) cron section.
8. **Do not install untrusted MCP servers.** MCP servers receive data from Claude Code's tool responses. Only connect servers you trust.
9. **Disconnect ADB when not using it.** Toggle off Wireless Debugging in Developer Options.
10. **Never use ADB wireless debugging on public WiFi.** The debugging daemon listens on a network-accessible port. Any device on the same network can attempt to pair.

---

Last updated: 2026-04-18.
