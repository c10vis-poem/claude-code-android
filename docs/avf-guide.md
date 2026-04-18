# Android Virtualization Framework (AVF) -- Path C

> **Experimental.** AVF support is new. Claude Code has been installed, configured, and used for real work inside an AVF VM on our test device (Pixel 10 Pro, Android 16). This guide documents what we observed, including capabilities that exceeded expectations and limitations that remain. Google's documentation of AVF is extremely limited -- most of what follows was discovered through hands-on testing.

> **Android 17 Beta status (2026-04-18):** This guide reflects testing on Android 16. Android 17 Beta has not been re-verified end-to-end. Schema fields in `vm_config.json`, paths under `/mnt/internal/linux/`, GPU acceleration scope, and crosvm launch flags may have changed. Treat the specifics in this guide as a baseline to compare against, not as a current-on-A17 spec.

![Status: Experimental](https://img.shields.io/badge/Status-Experimental-orange.svg)

---

## What AVF Is

Android Virtualization Framework (AVF) is Google's built-in hypervisor for running Linux VMs directly on Android. Starting with Android 16, supported devices include a Terminal app that boots a Debian VM with a real Linux kernel. Unlike proot-distro (Path B), which uses syscall translation, AVF runs an actual VM -- `process.platform === "linux"`, native `/tmp`, no proot overhead.

The VM runs on crosvm (Chrome OS's virtual machine monitor), managed by Android's VirtualizationService with pKVM providing hardware-level isolation.

---

## Device Requirements

| Requirement | Details |
|-------------|---------|
| **Chipset** | Google Tensor (Pixel 6 and later). Some Exynos models may work but are untested. |
| **Android version** | Android 16 or later |
| **Developer Options** | Must be enabled |
| **WiFi or data** | Required for initial ~761 MB Debian image download |

**Samsung and Snapdragon devices are not supported.** Qualcomm only supports "protected" VMs at EL2, but the Terminal app requires non-protected VMs. Knox RKP on Samsung conflicts with AVF at the hypervisor level. This is a hardware/firmware limitation with no software workaround on stock firmware.

---

## Setup Checklist

Tested on a single Pixel 10 Pro running Android 16, 2026-04-01. Steps may vary on other Pixel models. Your experience may differ.

### 1. Enable Developer Options

Settings > About phone > tap **Build number** 7 times.

### 2. Enable Linux Development Environment

Settings > System > Developer options > **Linux development environment** > toggle ON.

(The setting is labeled "(Experimental) Run Linux terminal in Android".)

### 3. Disable Child Process Restrictions

While in Developer options, toggle **Disable child process restrictions** ON. This prevents Android from killing excess background processes spawned by the VM and Claude Code.

### 4. Launch Terminal App

The Terminal app appears automatically after enabling the Linux development environment. Open it. It will download a Debian image (~761 MB as of April 2026). Use WiFi or a strong data connection.

### 5. Configure App Settings (Critical)

These settings help prevent Android from killing the VM in the background:

1. Settings > Apps > Terminal > Permissions > enable **Notifications**
2. Settings > Apps > Terminal > **Turn OFF "Manage app if unused"**
3. Settings > Apps > Terminal > App battery usage > set to **Unrestricted**
4. Settings > Battery > **Battery saver: OFF**
5. Settings > Battery > **Adaptive battery: OFF** (recommended -- prevents Android from throttling the VM; Google says it "learns" usage patterns, but this is unverified for continuous VM workloads)

### 6. Screen-Off Stability (ADB Hardening) -- Semi-Fix

The VM may be killed when the screen turns off. This is the most-reported AVF issue across all platforms.

In our testing, the following ADB commands improved screen-off stability but did not fully solve the problem. The Terminal app Activity can still get recreated by Android (for example, when another app triggers a configuration change), which disrupts the terminal session even though the VM itself may survive. These commands are run from inside the VM after establishing an ADB connection to the host (see the [ADB From Inside the VM](#adb-wireless-from-inside-the-vm) section):

```bash
# Add Terminal app to deviceidle whitelist (prevents doze killing)
adb shell cmd deviceidle whitelist +com.android.virtualization.terminal

# Set app standby bucket to active (prevents Android from deprioritizing)
adb shell am set-standby-bucket com.android.virtualization.terminal active

# Grant background run permissions
adb shell cmd appops set com.android.virtualization.terminal RUN_IN_BACKGROUND allow
adb shell cmd appops set com.android.virtualization.terminal RUN_ANY_IN_BACKGROUND allow

# Exempt from power restrictions
adb shell cmd appops set com.android.virtualization.terminal SYSTEM_EXEMPT_FROM_POWER_RESTRICTIONS allow
```

**Important caveats:**
- These commands improved stability in our testing but are **not a complete fix**. The Terminal app Activity can still get recreated by Android (for example, when another app triggers a configuration change), which disrupts the terminal session even though the VM itself survives.
- We observed the VM surviving screen-off and even always-on-display-off after applying these commands, but this was on a single device during a single session. Longer-term stability is unconfirmed.
- These settings may need to be reapplied after a device reboot.

If ADB is not available, set your screen timeout as long as possible, or keep the screen on during active sessions.

---

## VM Configuration

The VM's configuration file is located at `/mnt/internal/linux/vm_config.json` inside the VM, and is writable with sudo. In our testing, we observed the following fields and their effects:

| Field | Default | Observed Effect |
|-------|---------|-----------------|
| `memory_mib` | 4096 | Controls RAM allocation. We changed this to 8192 on a device with 16 GB total RAM, and the VM booted successfully with ~7.7 GB available. Edit this field and restart the VM to apply. |
| `auto_memory_balloon` | true | When true, Android can dynamically reclaim VM RAM. Setting to false prevented this in our testing. |
| `boot_timeout_secs` | 20 | How long Android waits for the VM to boot before giving up. We increased to 60 for extra margin. |
| `protected` | false | The VM runs without verified boot. This means custom kernel loading is theoretically possible, though we did not test it. |
| `name` | "crosvm_debian" | Display name. Cosmetic. |

To edit:

```bash
sudo nano /mnt/internal/linux/vm_config.json
```

Changes take effect on the next VM restart (close and reopen the Terminal app).

**Note:** When we doubled RAM from 4096 to 8192, the zram swap also scaled automatically from ~977 MB to ~1.9 GB (roughly RAM/4). The VM reported 7.7 GB total RAM with 7.0 GB available after boot. zram swap is configured by default -- no manual setup is needed.

---

## Claude Code Installation Inside AVF

Once the Terminal app is running and you have a Debian shell:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Then fix your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Launch Claude Code:

```bash
claude
```

Authenticate via OAuth as normal.

**Copy-paste warning:** The AVF terminal has unreliable copy-paste behavior. Long commands and multi-line commands frequently break when pasted. Type commands manually or verify pasted text character by character before running.

---

## What We Observed Working

These capabilities were confirmed through direct testing on our Pixel 10 Pro. Results on other devices may vary.

### Core Environment
- **Real Linux kernel (6.12.60).** No syscall translation, no proot overhead. `process.platform === "linux"`.
- **Native `/tmp`.** No bind mounts, no `TMPDIR` workarounds, no `CLAUDE_CODE_TMPDIR` needed.
- **Standard `apt` package management.** Full Debian 13 (trixie) package ecosystem. `sudo apt update` and `sudo apt upgrade` work normally, including systemd package updates.
- **Claude Code installs via official installer.** No npm, no Node.js version management, no ripgrep symlink needed.
- **Python 3.13.5 pre-installed.** Node.js, GCC, and make are NOT pre-installed but can be installed via apt.
- **SSH running by default** on port 22.
- **systemd fully functional.** Service management, timers, and journals all work. Updating systemd via apt worked without issues in our testing.

### Hardware and Performance
- **8 CPU cores visible** (1x Cortex-X4, 2x Cortex-A725, 5x Cortex-A520 on our Tensor G5 test device). Full big.LITTLE topology exposed via `--host-cpu-topology`.
- **103 GB root disk.** Observed 552 MB/s sequential write and 4.2 GB/s sequential read using dd with default flags; the read figure includes page cache, so real disk throughput is lower. The original disk benchmark tool (fio) could not run due to a kernel limitation (see Known Issues).
- **zram swap** configured by default, scales proportionally with RAM allocation. No manual setup needed.

### Audio
- **Audio playback and recording confirmed.** PulseAudio 17.0 running as daemon, VirtIO SoundCard detected. Both playback (aplay, speaker-test) and capture (arecord) succeeded. Whether sound actually reached the phone speaker through AVF's audio routing pipeline was not conclusively verified.

### GUI Capability
- **Headless rendering works.** Firefox ESR ran in headless mode and successfully rendered web pages to screenshot files.
- **Wayland compositor available.** cage (kiosk compositor) ran with the headless backend. wayvnc can serve the output over VNC. Full interactive Firefox in a compositor crashed due to the software renderer's limitations, but headless screenshots worked.
- **Mesa/OpenGL/EGL stack pre-installed.** GPU device at `/dev/dri/card0` via virtio-gpu (PCI ID 1AF4:1050). Pixel 10 has gfxstream GPU acceleration; older Pixels use Lavapipe (CPU software rendering).

### Networking and Kernel Features
- **All 41 Linux capabilities present** in our testing (unrestricted VM).
- **iptables works** via `iptables-legacy` (not nftables -- see Known Issues).
- **FUSE, OverlayFS, BPF, seccomp** all functional.
- **systemd-nspawn available** for lightweight containerization.
- **inotify, mmap, loop devices, ext4** all work as expected.
- **Ping works** using unprivileged ICMP sockets.
- **TUN device available** at `/dev/net/tun` (VPN support possible).

### Android Storage Access
- `/mnt/shared` and `/mnt/internal` provide access to Android storage from inside the VM.
- `/mnt/internal/linux/vm_config.json` is the VM configuration file (writable with sudo).

---

## ADB Wireless From Inside the VM

In our testing, ADB wireless debugging worked from inside the VM, connecting to the host phone. This provides access to battery status, thermal data, display info, logcat, dumpsys, and device management -- capabilities not otherwise available from inside the isolated VM.

**How it worked in our testing:**

1. Enable Wireless Debugging on the phone (Settings > Developer options > Wireless debugging)
2. Tap "Pair device with pairing code" to get the pairing port and code
3. From inside the VM, pair using the phone's Wi-Fi IP (not localhost, not the virtual gateway):

```bash
adb pair <phone-wifi-ip>:<pairing-port> <code>
```

4. Scan for the connection port (it is different from the pairing port and rotates each session):

```bash
adb connect <phone-wifi-ip>:<connection-port>
```

**Pairing tip:** Use split-screen mode with Settings and Terminal side by side. The pairing code and port disappear when you leave the Wireless Debugging screen in Settings, so you need both visible simultaneously to enter the code before it expires.

**What we observed:**
- The connection uses the phone's Wi-Fi IP address, not `127.0.0.1` or the virtual network gateway
- Pairing codes expire quickly -- pair immediately after opening the dialog
- ADB pairing survived VM restarts in our testing -- only the connection needed to be re-established (with a new port scan)
- The connection port rotates each Wireless Debugging session
- Once connected, commands like `adb shell dumpsys battery`, `adb shell dumpsys thermalservice`, and `adb logcat` all worked

**What ADB unlocks from inside the VM:**
- Battery status, thermal monitoring, display info
- Logcat (system logs from the Android host)
- App management (dumpsys, am, pm)
- Device settings (get/set system properties)
- Input injection (tap, swipe, text)
- The screen-off stability commands described in the Setup section
- Hardware sensor access, GPS, camera, screenshots, and more (see next section)

---

## ADB Hardware Access

With ADB connected from inside the VM to the Android host, we tested access to phone hardware. This was observed in our testing on a single device.

### Sensor Inventory

42 hardware sensors were enumerable via `adb shell dumpsys sensorservice`. The sensor categories observed:

| Category | Sensors | Example Chips |
|----------|---------|---------------|
| **Motion** | Accelerometer, gyroscope (calibrated + uncalibrated), linear acceleration, gravity, rotation vectors (3 types), orientation | ICM45631 (Invensense) |
| **Magnetic** | Magnetometer (calibrated + uncalibrated), geomagnetic rotation vector | MMC5616 (MEMSIC) |
| **Environmental** | Barometer, ambient light, color sensor, rear light | SPL07003 (Goermicro), TMD3743 (AMS), VD6282 (STMicro) |
| **Proximity/Gesture** | Proximity, tilt, lift to wake, significant motion, device orientation | TMD3743 (AMS), Google fusion |
| **Activity** | Step detector, step counter (require ACTIVITY_RECOGNITION permission) | Google fusion |
| **Temperature** | Gyro temperature, pressure temperature | Invensense, Goermicro |
| **Camera/System** | Camera V-Sync (4 instances), dynamic sensor manager, motion detect, stationary detect | Google, ICM45631 |

Sensors ranged from 10Hz (proximity) to 400Hz (accelerometer/gyroscope). Several were actively reporting data at the time of the query.

**Limitation:** `dumpsys sensorservice` shows which sensors exist, their sampling rates, and which are currently active, but does not expose raw X/Y/Z values in a pipeable format. Live sensor value streaming needs pipeline work (see below).

### GPS / Location

`adb shell dumpsys location | grep "last location"` returned location data including latitude/longitude coordinates with ~11.5m horizontal accuracy and sub-meter vertical accuracy. Both network and fused location providers were active.

### Camera

`adb shell am start -a android.media.action.IMAGE_CAPTURE` opened the camera app from inside the VM. The viewfinder was visible and a screenshot of it could be captured via `adb shell screencap`. Camera capabilities included front + rear cameras, up to 4032x3024 stills and 4K video, with multiple focus modes.

### Screenshots and Screen Recording

```bash
# Screenshot
adb shell screencap -p /sdcard/shot.png && adb pull /sdcard/shot.png

# Screen recording (3 seconds)
adb shell screenrecord --time-limit 3 /sdcard/vid.mp4 && adb pull /sdcard/vid.mp4
```

Both worked reliably in our testing. Screenshots ranged from 202KB to 777KB depending on content. Screen recordings transferred at ~80 MB/s to the VM.

### Input Injection

```bash
adb shell input text "hello"         # Type text into focused field
adb shell input tap 500 1000         # Tap screen coordinates
adb shell input swipe 100 500 100 100  # Swipe gesture
```

All input injection commands worked in our testing. The device reported multitouch support with 10 touch slots and pressure sensitivity.

### Battery and WiFi

```bash
# Battery
adb shell dumpsys battery
# Returns: status, level (%), voltage (mV), temperature

# WiFi
adb shell dumpsys wifi | grep mWifiInfo
# Returns: frequency, link speed, signal strength, security type
```

Both returned detailed real-time data in our testing. Battery data included charge level, voltage, and temperature. WiFi data included connection frequency, link speeds (TX/RX), signal strength in dBm, and security protocol.

### Needs Pipeline Work

- **Live sensor value streaming:** The 42 sensors are enumerable but raw values (X/Y/Z accelerometer data, etc.) are not available in a pipeable format via `dumpsys`. Options include writing a minimal Android app, polling `dumpsys` in a loop, using Termux:API as a sensor bridge, or parsing `adb shell getevent` for raw input events.
- **Camera photo capture to file:** The camera app opens but programmatically taking a photo and saving it to a retrievable path needs either an intent with an output URI (`am start -a IMAGE_CAPTURE --eu output file:///sdcard/photo.jpg`) or the screencap workaround (captures whatever is on screen, including the viewfinder).
- **Clipboard read:** Content access restricted on Android 13+. May need accessibility service or specific permissions.

### ADB Command Reference

```bash
# Sensor enumeration
adb shell dumpsys sensorservice

# GPS coordinates
adb shell dumpsys location | grep "last location"

# Camera launch
adb shell am start -a android.media.action.IMAGE_CAPTURE

# Screenshot
adb shell screencap -p /sdcard/shot.png && adb pull /sdcard/shot.png

# Screen recording
adb shell screenrecord --time-limit N /sdcard/vid.mp4 && adb pull /sdcard/vid.mp4

# Battery state
adb shell dumpsys battery

# Input injection
adb shell input text "hello"
adb shell input tap X Y

# WiFi info
adb shell dumpsys wifi | grep mWifiInfo
```

---

## Known Issues

| Issue | Impact | Workaround | Status |
|-------|--------|------------|--------|
| VM killed when screen off | Session lost, unsaved work gone | ADB whitelist commands (see Setup); keep screen on as fallback | ADB commands improved stability but are a semi-fix only. Terminal Activity can still get recreated. Google acknowledged at LPC 2025. |
| Terminal Activity recreation | Terminal UI disrupted even when VM survives | Avoid triggering Android configuration changes (rotation, accessibility overlays) while the terminal is active | Observed when enabling Voice Access accessibility service; the VM survived but the terminal session was lost |
| ~4 GB default RAM allocation | Limits what can run concurrently | Edit `memory_mib` in `/mnt/internal/linux/vm_config.json` (see VM Configuration section) | We successfully changed this to 8192 on a 16 GB device |
| Cellular data doesn't work by default | No network on mobile data | Settings > Apps > Terminal > enable "Unrestricted mobile data usage" > restart device. WiFi works without this step. | Google Issue Tracker #402523629 |
| Copy-paste unreliable | Multi-line commands break when pasted | Type manually or verify character by character | No fix known |
| `apt upgrade` can hang on TUI dialogs | Upgrade appears stuck indefinitely | Run with `DEBIAN_FRONTEND=noninteractive` or kill the blocking whiptail process | Observed during openssh-server post-install; whiptail required interactive input in a non-interactive shell |
| SysV IPC disabled in kernel | fio fails; some Python multiprocessing features unavailable | Use dd for disk benchmarks; use fork-based multiprocessing instead of shared memory | CONFIG_SYSVIPC is explicitly not set in the kernel. Hard wall. |
| nftables non-functional | Cannot use nft command despite kernel netfilter support | Use `iptables-legacy` instead: `sudo update-alternatives --set iptables /usr/sbin/iptables-legacy` | Kernel has CONFIG_NETFILTER=y but nftables operations return "Invalid argument" |
| No kernel module loading | Cannot extend kernel functionality at runtime | None -- kernel is monolithic, /lib/modules/ is empty | By design |
| "VM damaged" on unclean shutdown | Must reinstall entire VM | Commit/push work frequently; treat VM storage as ephemeral | By design -- Terminal app marks any unclean shutdown as damaged |
| Samsung/Snapdragon not supported | Terminal option greyed out or absent | None on stock firmware | Hardware/firmware limitation |
| No USB passthrough | Cannot access USB devices from VM | None | No USB host controller emulated by AVF |
| No phone sensors directly in VM | Camera, GPS, accelerometer, etc. not available inside VM natively | Access via ADB bridge -- 42 sensors enumerable, GPS and camera accessible (see ADB Hardware Access section) | Sensors confirmed enumerable. Live value streaming needs pipeline work. |
| VM IP changes per boot | Scripts using hardcoded VM IPs break | Query IP dynamically at boot | Virtual network interface gets a new address each time |
| GPU acceleration limited | Pixel 10 only (via gfxstream). All other Pixels use Lavapipe (CPU software renderer) -- slow, high power draw. | CLI-only usage avoids GPU entirely | QPR2 Beta 3 added Pixel 10 GPU support |

---

## Security Defaults -- Users Should Be Aware

The VM ships with defaults that prioritize convenience over security. In our testing, we observed the following. Users should consider whether hardening is appropriate for their use case.

| Default | Detail | Suggested Hardening |
|---------|--------|---------------------|
| Default user password | The "droid" user (UID 1000) has a known default password set by cloud-init | Change with `sudo passwd droid` |
| SSH password auth enabled | `/etc/ssh/sshd_config` has `PasswordAuthentication yes` | Set to `no` and use key-based auth |
| NOPASSWD sudo | The droid user has passwordless sudo | Consider adding a password requirement if others share the device |
| No firewall configured | All iptables chains default to ACCEPT | Configure iptables-legacy rules (see Known Issues for nftables limitation) |
| SSH key on shared storage | A default SSH key may be generated at `/mnt/shared/Documents/` where any Android app can read it | Remove the key file and regenerate in the VM's `~/.ssh/` |
| Unnecessary services | exim4 mail server may be running on port 25 (localhost) | `sudo systemctl disable --now exim4` |

The VM is on a virtual network not directly reachable from the internet. Only the Android host can reach it. The primary exposure vector is ADB wireless debugging on the Wi-Fi network, which requires explicit pairing.

---

## What Works Well

- **Real Linux kernel.** No syscall translation, no proot overhead. Native performance.
- **`process.platform === "linux"`.** No platform detection issues. Tools that check for Linux work without patching.
- **Native `/tmp`.** No bind mounts, no `TMPDIR` workarounds, no `CLAUDE_CODE_TMPDIR` needed.
- **Standard package management.** `apt` works normally. Full Debian package ecosystem available. System packages including systemd can be updated without issues.
- **Claude Code installs via official installer.** No npm, no Node.js version management, no ripgrep symlink needed.
- **RAM is configurable.** The default 4 GB allocation can be changed by editing `memory_mib` in the VM config file.
- **ADB bridge to phone.** Wireless debugging from inside the VM provides access to 42 phone sensors, GPS, camera, screenshots, screen recording, input injection, battery, and WiFi data.
- **Audio pipeline.** PulseAudio, ALSA, playback and capture all functional.
- **GUI headless rendering.** Firefox screenshots, automated browser testing, and similar headless workflows work.
- **Isolation.** VM is separated from Android. Crashes don't affect the host OS.

---

## Comparison: Path A vs Path B vs Path C

| | Path A (Native Termux) | Path B (Ubuntu in Termux) | Path C (AVF VM) |
|---|---|---|---|
| **Setup time** | ~2 min (experienced) | ~10-15 min (experienced) | ~20 min (experienced) |
| **Disk usage** | Minimal | ~2 GB | ~2 GB (Debian image) |
| **Install method** | npm | Official Anthropic installer | Official Anthropic installer |
| **Linux kernel** | No (Android kernel + syscall translation) | No (proot syscall translation) | Yes (real VM kernel) |
| **`/tmp` workaround** | Required every launch | Not needed | Not needed |
| **Ripgrep fix** | Required, breaks on updates | Not needed | Not needed |
| **`process.platform`** | `"android"` (causes issues) | `"linux"` | `"linux"` |
| **RAM** | Shares device RAM | Shares device RAM | Configurable (default 4 GB, adjustable via config) |
| **Termux API access** | Full (camera, TTS, GPS, SMS, sensors) | Full (via PATH extension) | None directly (extensive access via ADB bridge -- 42 sensors, GPS, camera, screenshots, input) |
| **ADB self-connect** | Works (127.0.0.1) | Works (127.0.0.1) | Works (via Wi-Fi IP, observed in our testing) |
| **Device support** | Any ARM64 Android 14+ | Any ARM64 Android 14+ | Pixel 6+ with Android 16+ only |
| **Stability** | Stable | Stable | Experimental -- VM may be killed |
| **Ongoing maintenance** | Re-fix after each update | Just update normally | Just update normally (if VM survives) |
| **Audio** | Via Termux API | Via Termux API | Native (PulseAudio + VirtIO) |
| **GUI capability** | Limited | Limited | Headless rendering confirmed; interactive compositor possible |
| **Best for** | Experienced users, light usage | Everyone else | Experimenters with Pixel devices who want native Linux |

---

## When to Use AVF vs Termux

**Use Path C (AVF) when:**
- You have a Pixel 6 or later running Android 16+
- You want a real Linux environment with native `/tmp` and `process.platform === "linux"`
- You want to configure VM RAM independently from Android
- You want native audio, headless GUI rendering, or systemd services
- You don't need direct Termux API access (though ADB bridge provides sensor, GPS, camera, and input access)
- You're comfortable with experimental software that may lose work on unexpected shutdown
- You want the cleanest Claude Code install experience (official installer, no workarounds)

**Use Path A or B (Termux) when:**
- You have any ARM64 Android 14+ device (Samsung, OnePlus, Pixel, etc.)
- You need Termux API features
- You need stability -- Termux doesn't get killed by Android's memory management the same way
- You want a proven path that has been tested across multiple devices and Android versions

**Use both when:**
- You want AVF for pure Linux development and Termux for Android API integration
- They coexist on the same device without conflict

---

## Community Resources

| Resource | What |
|----------|------|
| [Android Authority: Memory fix](https://androidauthority.com/android-linux-terminal-memory-fix-3555799/) | zram + swap workaround for OOM kills |
| [Android Authority: Pixel 10 GPU acceleration](https://androidauthority.com/pixel-10-linux-apps-gpu-acceleration-3608754/) | GPU support status and device coverage |
| [Android Authority: Desktop Linux apps hands-on](https://androidauthority.com/run-desktop-linux-apps-on-android-how-to-3586539/) | Practical walkthrough of GUI apps in AVF |
| [lfdevs/run-linux-on-android-guide](https://github.com/lfdevs/run-linux-on-android-guide) | Community setup guide (39 stars) |
| [nixos-avf](https://github.com/nix-community/nixos-avf) | NixOS in AVF VM (288 stars, actively maintained) |
| [Google Issue Tracker: AVF bugs](https://issuetracker.google.com/issues/new?component=190602&template=2068275) | File bugs (no dedicated AVF component -- goes to generic Android Platform) |
| [SSH + Tailscale workaround](https://gist.github.com/aschober/eeb316027c5037fc3af5fb0327ab44fd) | Access VM from outside localhost |
| [gunyah-on-sd-guide](https://github.com/polygraphene/gunyah-on-sd-guide) | VMs on Snapdragon via Qualcomm's Gunyah hypervisor (111 stars, non-stock firmware) |
| [Google source: AVF architecture](https://source.android.com/docs/core/virtualization/architecture) | Official AVF architecture documentation |
| [LPC 2025: "A Linux VM on Android via AVF"](https://news.ycombinator.com/item?id=46262802) | Most detailed technical presentation on AVF internals (Linux Plumbers Conference, Dec 2025) |

---

## Technical Details (For the Curious)

These details were observed during our testing session. They may be useful for advanced users or anyone trying to understand the VM's architecture.

### Virtual Hardware Inventory

The VM includes a rich set of virtual devices (enumerated via lspci):

- Intel 440FX host bridge (compatibility shim)
- Virtio 1.0 GPU (PCI ID 1AF4:1050)
- 3x Virtio console devices
- 2x Virtio block devices (root disk + config)
- Virtio RNG (hardware random number generator)
- 4x Virtio input devices (touchscreen, keyboard, mouse, trackpad)
- Virtio balloon (memory management)
- Virtio network device
- VirtIO SoundCard
- Virtio socket (vsock for VM-host communication)
- 2x Virtio filesystem devices (/mnt/shared, /mnt/internal)
- PVPanic device (crash reporting)

### Kernel Details

- Kernel 6.12.60-android16-6, built with Android Clang 19.0.1 (with PGO, BOLT, LTO, MLGO optimizations)
- Monolithic kernel (no loadable modules, /lib/modules/ empty)
- CONFIG_SYSVIPC and CONFIG_POSIX_MQUEUE explicitly disabled
- CONFIG_BPF, CONFIG_NETFILTER, CONFIG_KVM, CONFIG_FUSE_FS, CONFIG_OVERLAY_FS, CONFIG_VETH all enabled
- CONFIG_BRIDGE_NETFILTER not set (Docker networking would not work without this)
- Seccomp available but not enforced
- No Yama ptrace restrictions

### Running Services

AVF-specific services observed at runtime:
- `forwarder-guest-launcher` -- port forwarding between VM and Android
- `storage-balloon-agent` -- dynamic storage management
- `ttyd` + `ttyd_vsock_bridge` + `ttyd_uds` -- web terminal via vsock (the Terminal app UI)
- `shutdown-runner` -- graceful VM shutdown coordination
- `avahi-daemon` -- mDNS/DNS-SD service discovery
- `ssh` -- OpenSSH server (port 22)
- `unattended-upgrades` -- automatic security updates

### crosvm Launch Parameters

Observed via `ps -ef` on the Android host:

```
crosvm_debian --mem 4096 --host-cpu-topology --virt-cpufreq
  --balloon-page-reporting --disable-sandbox --cid 2050
  --name crosvm_debian
```

Key flags: `--host-cpu-topology` exposes all CPU cores with their real frequency characteristics. `--balloon-page-reporting` enables dynamic memory management (controllable via `auto_memory_balloon` in config). `--disable-sandbox` runs crosvm without its internal sandbox. `--cid 2050` is the vsock context ID for VM-host communication.

---

*Last updated: 2026-04-18. Tested on Pixel 10 Pro, Android 16; Android 17 Beta status note added 2026-04-18. This is a single-device test -- your experience may differ. Google's AVF documentation remains extremely limited; most findings here were discovered empirically. If you test on a different device, please [open an issue](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.md) with your results.*
