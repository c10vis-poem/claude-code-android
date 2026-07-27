# Android Virtualization Framework (AVF): Path C

> **Experimental.** I have installed, configured, and used Claude Code inside the Android Virtualization Framework VM on Pixel 6 (Android 17) and Pixel 10 Pro (Android 17). This guide documents what I observed. Google's official AVF developer documentation lives at [source.android.com/docs/core/virtualization](https://source.android.com/docs/core/virtualization); user-facing behaviour described here was discovered on real devices.

> **Android 17 status (verified 2026-05-26):** The AVF path was retested end-to-end on Pixel 6 and Pixel 10 Pro running Android 17. Several things changed between Android 16 and Android 17 and this guide has been updated for the current behaviour:
>
> - Memory size, Display resolution, and Keep awake are adjusted in the Terminal app's gear-icon Settings under **Advanced**.
> - Keep awake keeps the VM running when the screen turns off. See the Screen-Off Stability section below.
> - SSH (Secure Shell) is not running by default. It is installed and can be enabled if you want it.
> - The Recovery section of Settings exposes "Reset to initial version" and "Remove backup data".
> - On Pixel 10 Pro, an additional **Graphics Acceleration** toggle (Software renderer or GPU-accelerated renderer) is available. Other Pixel models do not show this row.

![Status: Experimental](https://img.shields.io/badge/Status-Experimental-orange.svg)

---

## What AVF Is

In plain terms: Path C runs a real Linux computer inside your phone using Android's built-in virtualization. Everything below is detail for the curious; you do not need to understand it to use this path.

Android Virtualization Framework (AVF) is Google's built-in hypervisor (the software layer that runs virtual machines) for running Linux VMs directly on Android. Starting with Android 16, supported devices ship a Terminal app that boots a Debian VM with a real Linux kernel. Unlike proot-distro (Path B), which uses syscall translation, AVF runs an actual VM: `process.platform === "linux"`, native `/tmp`, no proot overhead.

The VM runs on crosvm (Chrome OS's virtual machine monitor), managed by Android's VirtualizationService, with pKVM (Android's paravirtualized KVM hypervisor) providing hardware-level isolation. Device I/O uses virtio (a standard interface for virtual devices). AOSP (Android Open Source Project) architecture reference: [source.android.com/docs/core/virtualization/architecture](https://source.android.com/docs/core/virtualization/architecture).

---

## Device Requirements

| Requirement | Details |
|-------------|---------|
| **Chipset** | Google Tensor (Pixel 6 and later) verified in my lab. Other chipsets vary by OEM; see below. |
| **Android version** | Android 16 or later |
| **Developer Options** | Must be enabled |
| **WiFi or data** | Required for the initial Debian image download (several hundred megabytes). Use WiFi. |

If your phone exposes Settings > System > Developer options > **Linux development environment**, your device supports this path. If that option is missing, it does not.

In my testing and per public reports, Snapdragon phones are not supported on stock firmware: Qualcomm exposes only "protected" VMs at EL2 (ARM Exception Level 2, the CPU privilege level a hypervisor runs at), but the Terminal app requires non-protected VMs. Knox RKP (Real-time Kernel Protection, Samsung's hypervisor-backed security feature) on older Samsung devices conflicted with AVF for the same family of reasons. Samsung support varies: Exynos-based Galaxy S26 and S26+ on One UI 8.5 are reported supported per Samsung's release notes, while the Snapdragon Galaxy S26 Ultra is not. I do not own a Samsung Exynos S26 or S26+, so I cannot confirm Samsung behaviour from first-hand testing.

---

## Setup Checklist

Verified on Pixel 6 and Pixel 10 Pro running Android 17 on 2026-05-26.

### 1. Enable Developer Options

Settings > About phone > tap **Build number** 7 times.

### 2. Enable Linux Development Environment

Settings > System > Developer options > **Linux development environment** > toggle ON.

If that toggle is not present, your device does not support this path.

### 3. Launch the Terminal App

A "Terminal" app appears on the home screen after step 2. Open it. On first launch, accept the prompt to download the Debian image. The download is several hundred megabytes; use WiFi.

When setup finishes, the app displays a shell prompt: `droid@debian:~$`. You are now inside the Linux VM.

### 4. Adjust Settings If You Want To

Tap the gear icon in the top right of the Terminal app to open Settings. The categories are:

- **Port control**: allow or deny ports that processes inside the VM open
- **Theming**: terminal color presets, plus import of custom themes
- **Advanced**: Display resolution, Memory size, Keep awake. On Pixel 10 Pro an additional Graphics Acceleration toggle appears.
- **Recovery**: "Reset to initial version" wipes the Debian image and re-downloads it. "Remove backup data" wipes `/mnt/backup`.

You can run Claude Code without changing any of these. The defaults work.

### 5. Screen-Off Stability (Keep Awake)

The VM is subject to Android's normal app-killing behaviour when the screen turns off. Android 17 adds a built-in mitigation in the Terminal app: Settings (gear) > Advanced > **Keep awake**.

Keep awake is a timer. The options are Off, 1 minute, 5 minutes, 10 minutes, 30 minutes, 1 hour, 2 hours, 6 hours, and 1 day. The in-app dialog warns: *"Enabling keep awake will significantly impact battery life as it prevents the device from sleeping."*

For short interactive sessions, leave it Off and keep the screen on. For long-running workloads, pick a value that matches how long you need the VM alive in the background.

The Terminal app's Activity (the on-screen window Android draws for the app) can still be recreated by Android in some cases (for example, when another app triggers a configuration change). Keep awake keeps the VM running but does not guarantee the terminal session UI stays continuous through every Android lifecycle event. If you need true long-running workloads, run them under `tmux` or `nohup` (tools that keep a process alive after its terminal window goes away) so they survive Activity recreation.

---

## VM Configuration

On Android 17, VM configuration is exposed in the Terminal app's gear-icon Settings under **Advanced**. The `/mnt` tree inside the VM contains `backup`, `build`, `shared`, and `ttyd` only.

The Advanced screen exposes:

| Control | What it does |
|---|---|
| **Display resolution** | Three presets: Full ("Performance might be degraded"), Half (labelled "Recommended" by the app), Quarter ("Quality might be degraded"). For CLI-only Claude Code use, the resolution does not matter. |
| **Memory size** | Integer megabyte input plus a slider. The code default is 1024 MiB ([AOSP `ConfigJson.kt`](https://android.googlesource.com/platform/packages/modules/Virtualization/+/refs/heads/main/android/TerminalApp/java/com/android/virtualization/terminal/ConfigJson.kt)). The slider maximum scales with the host device's total RAM (I observed roughly two-thirds of total). Changing this requires a Terminal restart. |
| **Keep awake** | Screen-off VM survival timer; see the Screen-Off Stability section above. |
| **Graphics Acceleration** | Software renderer or GPU-accelerated renderer. Only present on Pixel 10 Pro in my testing; absent on Pixel 6. Tied to whether the device ships the AVF graphics overlay. |

To apply changes, the Terminal app may prompt to restart the VM.

zram swap (compressed swap space held in RAM) is configured automatically inside the VM and scales with the memory allocation. No manual setup needed.

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

There is no automatic update or crash-rollback on Path C. The VM runs a real Linux kernel, so Anthropic's official installer works the same way it does on a PC. Update by re-running the installer.

**Copy-paste warning:** The AVF terminal has unreliable copy-paste behavior. Long commands and multi-line commands frequently break when pasted. Type commands manually or verify pasted text character by character before running.

---

## What I Observed Working

These capabilities were confirmed through direct testing on my Pixel 10 Pro. Results on other devices may vary.

### Core Environment
- **Real Linux kernel.** No syscall translation, no proot overhead. `process.platform === "linux"`. The kernel build is in the 6.12.x line on my Android 17 devices.
- **Native `/tmp`.** A real, writable `/tmp` directory inside the VM.
- **Standard `apt` package management.** Full Debian 13 (trixie) package ecosystem. `sudo apt update` and `sudo apt upgrade` work normally, including systemd package updates.
- **Claude Code installs via the official Anthropic installer.** No npm, no Node.js version management, no ripgrep symlink needed.
- **Python 3 pre-installed.** Node.js, GCC, and make are NOT pre-installed; install with `sudo apt install`.
- **OpenSSH is installed but not running by default.** Enable with `sudo systemctl enable --now ssh` if you want it.
- **systemd fully functional.** Service management, timers, and journals all work. Updating systemd via apt worked without issues in my testing.

### Hardware and Performance
- **8 CPU cores visible** (1x Cortex-X4, 5x Cortex-A725, 2x Cortex-A520 on my Tensor G5 test device). Full big.LITTLE topology (ARM's mix of high-performance and low-power cores) exposed via `--host-cpu-topology`.
- **103 GB root disk.** Observed 552 MB/s sequential write and 4.2 GB/s sequential read using dd with default flags; the read figure includes page cache, so real disk throughput is lower. The original disk benchmark tool (fio) could not run due to a kernel limitation (see Known Issues).
- **zram swap** configured by default, scales proportionally with RAM allocation. No manual setup needed.

### Audio
- **Audio playback and recording partially verified.** PulseAudio 17.0 running as daemon, VirtIO SoundCard detected. Both playback (aplay, speaker-test) and capture (arecord) succeeded. Whether sound actually reached the phone speaker through AVF's audio routing pipeline was not conclusively verified.

### GUI Capability
- **Headless rendering works.** Firefox ESR (Extended Support Release) ran in headless mode and successfully rendered web pages to screenshot files.
- **Wayland compositor available.** (Wayland is a modern Linux display system.) cage (kiosk compositor) ran with the headless backend. wayvnc can serve the output over VNC (Virtual Network Computing, a remote-desktop protocol). Full interactive Firefox in a compositor crashed due to the software renderer's limitations, but headless screenshots worked.
- **Mesa/OpenGL/EGL (Embedded Graphics Library, the interface between OpenGL and the display system) stack pre-installed.** GPU device at `/dev/dri/card0` via virtio-gpu. The Terminal app exposes a Graphics Acceleration toggle (Software renderer or GPU-accelerated renderer) on Pixel 10 Pro; on Pixel 6 the row is absent and the VM uses the software renderer.

### Networking and Kernel Features
- **All 41 Linux capabilities present** in my testing (unrestricted VM).
- **iptables works** via `iptables-legacy` (not nftables; see Known Issues).
- **FUSE (Filesystem in Userspace), OverlayFS, BPF (Berkeley Packet Filter, a Linux kernel programmability subsystem), seccomp** all functional.
- **systemd-nspawn available** for lightweight containerization.
- **inotify, mmap, loop devices, ext4** all work as expected.
- **Ping works** using unprivileged ICMP (Internet Control Message Protocol) sockets.
- **TUN device available** at `/dev/net/tun` (TUN is a virtual network kernel interface; VPN support is possible).

### Android Storage Access
- `/mnt/shared` is the Android shared-storage volume (the same place Android's "Files" app reads from). Anything placed there from Android is visible inside the VM, and vice versa.
- `/mnt/backup` is used by the Terminal app's Recovery feature for backup data.

---

## ADB Wireless From Inside the VM

In my testing, ADB wireless debugging worked from inside the VM, connecting to the host phone. This provides access to battery status, thermal data, display info, logcat, dumpsys, and device management. These capabilities are not otherwise available from inside the isolated VM.

**How it worked in my testing:**

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

**What I observed:**
- The connection uses the phone's Wi-Fi IP address, not `127.0.0.1` or the virtual network gateway
- Pairing codes expire quickly. Pair immediately after opening the dialog.
- ADB pairing survived VM restarts in my testing. Only the connection needed to be re-established (with a new port scan).
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

With ADB connected from inside the VM to the Android host, I tested access to phone hardware. This was observed in my testing on a single device.

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

Both worked reliably in my testing. Screenshots ranged from 202KB to 777KB depending on content. Screen recordings transferred at ~80 MB/s to the VM.

### Input Injection

```bash
adb shell input text "hello"         # Type text into focused field
adb shell input tap 500 1000         # Tap screen coordinates
adb shell input swipe 100 500 100 100  # Swipe gesture
```

All input injection commands worked in my testing. The device reported multitouch support with 10 touch slots and pressure sensitivity.

### Battery and WiFi

```bash
# Battery
adb shell dumpsys battery
# Returns: status, level (%), voltage (mV), temperature

# WiFi
adb shell dumpsys wifi | grep mWifiInfo
# Returns: frequency, link speed, signal strength, security type
```

Both returned detailed real-time data in my testing. Battery data included charge level, voltage, and temperature. WiFi data included connection frequency, link speeds (TX/RX), signal strength in dBm, and security protocol.

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
| VM killed when screen off | Session lost, unsaved work gone | Settings > Advanced > Keep awake (timer up to 1 day); keep screen on for short sessions | Built-in mitigation on Android 17. Battery impact applies; see warning text in the in-app dialog. |
| Terminal Activity recreation | Terminal UI disrupted even when VM survives | Run long workloads under `tmux` or `nohup` so they survive Activity recreation | Some Android lifecycle events (configuration changes, accessibility services) recreate the Activity even with Keep awake on |
| Default Memory size may be low | Limits what can run concurrently | Settings > Advanced > Memory size; raise the value (slider scales with device RAM); restart Terminal to apply | Code default is 1024 MiB per AOSP. The slider exposes the safe range for your device. |
| Cellular data doesn't work by default | No network on mobile data | Settings > Apps > Terminal > enable "Unrestricted mobile data usage" > restart device. WiFi works without this step. | Google Issue Tracker #402523629 |
| Copy-paste unreliable | Multi-line commands break when pasted | Type manually or verify character by character | No fix known |
| `apt upgrade` can hang on TUI (text-based user interface) dialogs | Upgrade appears stuck indefinitely | Run with `DEBIAN_FRONTEND=noninteractive` or kill the blocking whiptail process | Observed during openssh-server post-install; whiptail required interactive input in a non-interactive shell |
| SysV IPC disabled in kernel | fio fails; some Python multiprocessing features unavailable | Use dd for disk benchmarks; use fork-based multiprocessing instead of shared memory | CONFIG_SYSVIPC is explicitly not set in the kernel. Hard wall. |
| nftables non-functional | Cannot use nft command despite kernel netfilter support | Use `iptables-legacy` instead: `sudo update-alternatives --set iptables /usr/sbin/iptables-legacy` | Kernel has CONFIG_NETFILTER=y but nftables operations return "Invalid argument" |
| No kernel module loading | Cannot extend kernel functionality at runtime | None (kernel is monolithic, /lib/modules/ is empty) | By design |
| "VM damaged" on unclean shutdown | Must reinstall entire VM | Commit/push work frequently; treat VM storage as ephemeral | By design. Terminal app marks any unclean shutdown as damaged. |
| Snapdragon phones not supported (in my testing and per public reports) | Linux dev environment option absent | None on stock firmware | Qualcomm exposes only protected VMs at EL2; the Terminal app requires non-protected VMs. Samsung's Exynos S26 / S26+ on One UI 8.5 are reported supported per Samsung's release notes; I have not lab-verified Samsung Exynos behaviour. |
| No USB passthrough | Cannot access USB devices from VM | None | No USB host controller emulated by AVF |
| No phone sensors directly in VM | Camera, GPS, accelerometer, etc. not available inside VM natively | Access via ADB bridge: 42 sensors enumerable, GPS and camera accessible (see ADB Hardware Access section) | Sensors confirmed enumerable. Live value streaming needs pipeline work. |
| VM IP changes per boot | Scripts using hardcoded VM IPs break | Query IP dynamically at boot | Virtual network interface gets a new address each time |
| GPU acceleration limited | Pixel 10 Pro exposes a Graphics Acceleration toggle (GPU-accelerated renderer) in Settings > Advanced. Other Pixel models fall back to the software renderer. | CLI-only Claude Code use avoids the GPU entirely | Tied to the device's AVF graphics overlay package. Pixel 10 Pro ships it; Pixel 6 does not. |

---

## Security Defaults: Users Should Be Aware

The VM ships with defaults that prioritize convenience over security. In my testing on Android 17, I observed the following. Consider whether hardening is appropriate for your use case.

| Default | Detail | Suggested Hardening |
|---------|--------|---------------------|
| Default user password | The "droid" user (UID 1000) has a known default password set by cloud-init (the tool that does first-boot setup) | Change with `sudo passwd droid` |
| NOPASSWD sudo | The droid user has passwordless sudo | Add a password requirement if others share the device |
| No firewall configured | All iptables chains default to ACCEPT | Configure iptables-legacy rules (see Known Issues for nftables limitation) |
| SSH installed but inactive | OpenSSH is in the image but not started. If you enable it with `sudo systemctl enable --now ssh`, the default `sshd_config` permits password auth | Before enabling, set `PasswordAuthentication no` and use key-based auth |
| SSH key on shared storage | If you generate or move an SSH key into `/mnt/shared/`, any Android app with storage access can read it | Keep keys in the VM's `~/.ssh/`, not on shared storage |

The VM is on a virtual network not directly reachable from the internet. Only the Android host can reach it. The primary exposure vector is ADB wireless debugging on the Wi-Fi network, which requires explicit pairing.

---

## What Works Well

- **Real Linux kernel.** No syscall translation, no proot overhead. Native performance.
- **`process.platform === "linux"`.** No platform detection issues. Tools that check for Linux work without patching.
- **Native `/tmp`.** A real, writable `/tmp` directory inside the VM.
- **Standard package management.** `apt` works normally. Full Debian package ecosystem available. System packages including systemd can be updated without issues.
- **Claude Code installs via official installer.** No npm, no Node.js version management, no ripgrep symlink needed.
- **RAM is configurable.** Settings (gear) > Advanced > Memory size exposes an integer MB input and a slider scaled to your device's total RAM. The code default is 1024 MiB.
- **ADB bridge to phone.** Wireless debugging from inside the VM provides access to 42 phone sensors, GPS, camera, screenshots, screen recording, input injection, battery, and WiFi data.
- **Audio pipeline.** PulseAudio, ALSA (Advanced Linux Sound Architecture), playback and capture all functional.
- **GUI headless rendering.** Firefox screenshots, automated browser testing, and similar headless workflows work.
- **Isolation.** VM is separated from Android. Crashes don't affect the host OS.

---

## Comparison: Path A vs Path B vs Path C

| | Path A (Native Termux) | Path B (Ubuntu in Termux) | Path C (AVF VM) |
|---|---|---|---|
| **Setup time** | 5-10 min | ~10-15 min (experienced) | ~20 min (experienced) |
| **Disk usage** | ~280 MB base | ~2 GB | ~2 GB (Debian image) |
| **Install method** | Patched linux-arm64 binary via glibc-runner; auto-updating wrapper | Official Anthropic installer | Official Anthropic installer |
| **Linux kernel** | No (Android kernel + syscall translation) | No (proot syscall translation) | Yes (real VM kernel) |
| **`/tmp` workaround** | Not needed | Not needed | Not needed |
| **Ripgrep** | Not needed (binary ships vendor/ripgrep/arm64-linux/rg) | Not needed | Not needed |
| **`process.platform`** | `"linux"` (the patched binary is the linux-arm64 build) | `"linux"` | `"linux"` |
| **RAM** | Shares device RAM | Shares device RAM | Configurable in Terminal app Settings > Advanced > Memory size. Code default is 1024 MiB; slider scales with device RAM. |
| **Termux API access** | Full (camera, TTS, GPS, SMS, sensors) | Full (via PATH extension) | None directly (extensive access via ADB bridge: 42 sensors, GPS, camera, screenshots, input) |
| **ADB self-connect** | Works (127.0.0.1) | Works (127.0.0.1) | Works (via Wi-Fi IP, observed in my testing) |
| **Device support** | Any aarch64 Android 8+ (Android 8 / 9 have OAuth caveats; see FAQ) | Any aarch64 Android 8+ (Android 8 / 9 have OAuth caveats; see FAQ) | Pixel 6+ with Android 16+ only |
| **Stability** | Stable | Stable | Experimental (VM may be killed) |
| **Ongoing maintenance** | None (wrapper auto-updates) | Just update normally | Just update normally (if VM survives) |
| **Audio** | Via Termux API | Via Termux API | Native (PulseAudio + VirtIO) |
| **GUI capability** | Limited | Limited | Headless rendering confirmed; interactive compositor possible |
| **Best for** | Most users; the default path, start here | Users who want a full Debian/Ubuntu userland | Experimenters with Pixel devices who want native Linux |

---

## When to Use AVF vs Termux

**Use Path C (AVF) when:**
- You have a Pixel 6 or later running Android 16 or later (or a reported-supported Samsung Exynos S26 / S26+ on One UI 8.5)
- You want a real Linux environment with native `/tmp` and `process.platform === "linux"`
- You want to set VM memory and display resolution from a UI rather than work around Android's defaults
- You want native audio, headless GUI rendering, or systemd services
- You don't need direct Termux API access (the ADB bridge described above provides sensors, GPS, camera, and input access)
- You're comfortable with experimental software that may lose work on unexpected shutdown
- You want the cleanest Claude Code install experience (official installer, no workarounds)

**Use Path A or B (Termux) when:**
- You have any ARM64 Android 8+ device (Android 8 / 9 have OAuth caveats; see [FAQ](faq.md#claude-prints-a-url-but-my-browser-doesnt-open)) (Samsung, OnePlus, Pixel, etc.)
- You need Termux API features
- You need stability. Termux doesn't get killed by Android's memory management the same way.
- You want a proven path that has been tested across multiple devices and Android versions

**Use both when:**
- You want AVF for pure Linux development and Termux for Android API integration
- They coexist on the same device without conflict

---

## Community Resources

| Resource | What |
|----------|------|
| [Android Authority: Memory fix](https://androidauthority.com/android-linux-terminal-memory-fix-3555799/) | zram + swap workaround for OOM (out-of-memory) kills |
| [Android Authority: Pixel 10 GPU acceleration](https://androidauthority.com/pixel-10-linux-apps-gpu-acceleration-3608754/) | GPU support status and device coverage |
| [Android Authority: Desktop Linux apps hands-on](https://androidauthority.com/run-desktop-linux-apps-on-android-how-to-3586539/) | Practical walkthrough of GUI apps in AVF |
| [lfdevs/run-linux-on-android-guide](https://github.com/lfdevs/run-linux-on-android-guide) | Community setup guide |
| [nixos-avf](https://github.com/nix-community/nixos-avf) | NixOS in AVF VM (actively maintained) |
| [Google Issue Tracker: AVF bugs](https://issuetracker.google.com/issues/new?component=190602&template=2068275) | File bugs (no dedicated AVF component; goes to generic Android Platform) |
| [SSH + Tailscale workaround](https://gist.github.com/aschober/eeb316027c5037fc3af5fb0327ab44fd) | Access VM from outside localhost |
| [gunyah-on-sd-guide](https://github.com/polygraphene/gunyah-on-sd-guide) | VMs on Snapdragon via Qualcomm's Gunyah hypervisor (non-stock firmware) |
| [Google source: AVF architecture](https://source.android.com/docs/core/virtualization/architecture) | Official AVF architecture documentation |
| [LPC 2025: "A Linux VM on Android via AVF"](https://news.ycombinator.com/item?id=46262802) | Most detailed technical presentation on AVF internals (Linux Plumbers Conference, Dec 2025) |

---

## Technical Details (For the Curious)

These details were observed during my testing session. They may be useful for advanced users or anyone trying to understand the VM's architecture.

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
- Virtio filesystem devices backing `/mnt/shared` (Android shared storage) and `/mnt/backup` (Recovery backup volume)
- PVPanic device (crash reporting)

### Kernel Details

- Linux kernel in the 6.12.x line on my Android 17 devices, built as part of the Android GKI (Generic Kernel Image, Google's standardized Android kernel)
- Monolithic kernel (no loadable modules, `/lib/modules/` empty)
- `CONFIG_SYSVIPC` and `CONFIG_POSIX_MQUEUE` explicitly disabled. Tools that need SysV IPC or POSIX message queues will fail; `fio` is the most common one. `dd` works for disk benchmarks.
- `CONFIG_BPF`, `CONFIG_NETFILTER`, `CONFIG_BRIDGE_NETFILTER`, `CONFIG_KVM`, `CONFIG_FUSE_FS`, `CONFIG_OVERLAY_FS`, `CONFIG_VETH` all enabled
- Seccomp available but not enforced
- No Yama ptrace restrictions

### Running Services

AVF-specific services I observed active on Android 17:
- `forwarder-guest-launcher`: port forwarding between VM and Android
- `storage-balloon-agent`: dynamic storage management
- `ttyd` + `ttyd_vsock_bridge` + `ttyd_uds`: web terminal via vsock (the Terminal app UI)
- `shutdown-runner`: graceful VM shutdown coordination
- `unattended-upgrades`: automatic security updates

OpenSSH, avahi-daemon, and exim4 are installed in the Debian image but not started by default. Enable them with `sudo systemctl enable --now <service>` if you need them.

### crosvm Launch Behaviour

The Terminal app launches the VM via Android's VirtualizationService, which in turn runs `crosvm` with the host CPU topology exposed, dynamic memory ballooning (page reporting) enabled, hugepages, and the host-side audio + filesystem vhost-user sockets wired up. USB passthrough and the kernel PMU (Performance Monitoring Unit) are both disabled. Memory size, display resolution, and graphics-acceleration backend reflect whatever you have set in Settings > Advanced; CID (Context Identifier, used by vsock for VM addressing) and TAP-interface (a virtual network interface) address are assigned per VM launch and are not user-configurable.

---

*Last updated: 2026-07-01. AVF path re-verified end to end on Pixel 6 (Android 17) and Pixel 10 Pro (Android 17) on 2026-05-26. Earlier baseline testing on Pixel 10 Pro, Android 16, dated 2026-04-01. AOSP architecture reference: [source.android.com/docs/core/virtualization](https://source.android.com/docs/core/virtualization). If you test on a different device, please [open an issue](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.yml) with your results.*
