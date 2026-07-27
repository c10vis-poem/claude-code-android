# FAQ

Claude Code is Anthropic's terminal-based coding assistant: you run it from a command line and it reads, edits, and runs code in your project for you. This page covers common questions and gotchas for running it on Android.

This repo offers three install methods, referred to throughout as Path A, Path B, and Path C. See [Choosing a path](#choosing-a-path) below for what each one is.

Two different version numbers come up here. This repo has its own version (currently 2.9.x); Claude Code, the tool it installs, has its own separate version (currently 2.1.x). They are unrelated numbering schemes.

---

## Installation

### "Unsafe app blocked" when installing the Termux APK

Termux is a terminal-emulator app for Android. Its APK is distributed through F-Droid, an open-source Android app store.

On Android 11 and newer, Google Play Protect flags the F-Droid Termux APK (which targets SDK 28) as "built for an older version of Android." This is a Play Protect warning about the SDK target level, not a malware flag. The APK is signed by Termux's maintainers; in my testing it installs and runs without issues.

To proceed:

1. Tap **More details** in the dialog
2. Tap **Install anyway**

Or install Termux through the F-Droid app instead of side-loading the APK directly. The F-Droid app handles this dialog inline.

### install.sh hangs or fails with "Failed to fetch"

Termux's `pkg` (the package manager, a wrapper around apt with automatic mirror selection) picks a mirror automatically from a list of about 18 candidates worldwide. The picker is weighted by reachability, but the result is non-deterministic: a fresh Termux on the same device can pick different mirrors on different days. Some mirrors are slow or temporarily unreachable from your network, which can hang `pkg update` or `pkg install` for 10+ minutes before erroring out.

If you see "Failed to fetch" errors or `pkg update` hangs, change the mirror:

```bash
termux-change-repo
```

Pick a different mirror (the menu shows region groupings). Re-run install.sh after the new mirror is set.

### "Y/I/N/O/D/Z" prompt during `pkg upgrade`

When Termux upgrades a package whose config file was locally modified, apt asks what to do:

```
Configuration file '/path/to/config'
 ==> Modified (by you or by a script) since installation.
 ==> Package distributor has shipped an updated version.
*** filename (Y/I/N/O/D/Z) [default=N] ?
```

What the letters mean:

- **Y** or **I**: install the package maintainer's new version (overwrites your local changes)
- **N** or **O**: keep your old (current) version (this is the default)
- **D**: show the diff between your version and the new one
- **Z**: drop to a shell so you can investigate before deciding

You only need one letter. (Optional detail: there are two letters per choice because `Y/N` is the common convention and `I/O`, for "Install" / "Old", is the older dpkg convention. Both still work.)

To handle this non-interactively and keep all local config files unchanged:

```bash
DEBIAN_FRONTEND=noninteractive pkg upgrade -y -o Dpkg::Options::="--force-confold"
```

### Which packages should I install after `install.sh`?

`install.sh` installs what is needed to run claude itself: `curl`, `jq`, `glibc-repo`, `glibc-runner`, `patchelf-glibc`, and the patched linux-arm64 claude binary. It does NOT install `nodejs`; the binary is self-contained. If you answer yes to the recommended-packages prompt, it also installs git, gh, wget, jq, python, openssh, tree, proot, termux-api, proot-distro, make, clang, file, xxd, htop, bat, and fzf. If you say no to that prompt, vanilla Termux still gives you `unzip`, `tar`, `gzip`, `less`, and `nano` from its bootstrap, but Claude Code typically reaches for the recommended-packages set as well. See **[Recommended Common Packages](install.md#recommended-common-packages)** in install.md for the canonical list.

### Which install do I have: pinned or the native v2.9.x setup?

`claude --version` will not tell you: it reports Claude Code's own version (the 2.1.x number), which is the same on both. Check what is on disk instead:

```bash
if [ -d "$PREFIX/lib/node_modules/@anthropic-ai/claude-code" ]; then
  echo "pinned install (Claude Code 2.1.112 via npm)"
elif ls "$HOME/.local/share/claude/versions/"*.*.* >/dev/null 2>&1; then
  echo "native Path A install (the v2.9.x auto-updating wrapper)"
else
  echo "no recognized claude install found here"
fi
```

If you are on the pinned install and want current claude, see [I set up Path A with an older version of this repo](#i-set-up-path-a-with-an-older-version-of-this-repo-how-do-i-move-to-v290).

---

## Choosing a path

### Which path should I use?

| If you want | Pick |
|---|---|
| The smallest install, latest claude, auto-updates | Path A (native Termux) |
| A full Ubuntu environment alongside Claude Code | Path B (proot-distro Ubuntu, ~2 GB rootfs) |
| A real Linux kernel via Android's hypervisor (Pixel 6+ on Android 16+) | Path C (AVF, Android Virtualization Framework) |

All three paths install the latest claude. Path A's wrapper auto-checks once per 24 hours on launch (`claude --update-now` forces immediate). Paths B and C use Anthropic's official installer inside their Linux environments and update through that mechanism.

### Can I run Path C (AVF) on my Samsung, OnePlus, or Snapdragon phone?

Probably not on stock firmware. Path C needs Android's Virtualization Framework exposed as a non-protected VM, and Snapdragon devices on stock firmware only expose protected VMs at EL2, so the Terminal app cannot use them. The quick test: look for Settings > System > Developer options > **Linux development environment**. If that toggle is there, your device supports Path C; if it is missing, it does not.

Samsung's One UI 8.5 added Linux Terminal support on the Exynos Galaxy S26 and S26+, per Samsung's release notes. I do not own one, so I have not lab-verified it. The Snapdragon Galaxy S26 Ultra stays unsupported. See [avf-guide.md](avf-guide.md#device-requirements) for the full device picture.

### Why does Path A need patchelf and glibc-runner?

You do not need to understand any of this to use Path A; the installer does it all for you. The detail is here for the curious.

Anthropic distributes Claude Code as a glibc-linked Linux binary (as of v2.1.113; the upstream tracking issue is linked below). Termux runs on Android's Bionic C library, not glibc, so the binary cannot run as-is. Path A installs Termux's `glibc-runner` package (a Termux package that provides a glibc-compatible dynamic linker, `ld.so`, for running glibc binaries in Bionic-based environments) and uses `patchelf-glibc` (a Termux-packaged patchelf utility for modifying ELF (Executable and Linkable Format) binary metadata) to rewrite the binary's ELF interpreter (the field in the binary that names which dynamic linker to use) to point at that `ld.so`. The kernel can then exec the binary normally. Path B sidesteps this by running claude inside a proot-distro Ubuntu environment where glibc is already standard.

Tracked upstream at [anthropics/claude-code#50270](https://github.com/anthropics/claude-code/issues/50270). The patched-binary approach was originally described in [a comment on the upstream issue](https://github.com/anthropics/claude-code/issues/50270#issuecomment-4467292215). This repo's install.sh adapts it with empirical verification, an auto-updating wrapper, and the two interactive prompts.

### I set up Path A with an older version of this repo. How do I move to v2.9.0?

Use the migration script. It moves a pinned Path A install (Claude Code `2.1.112`, with the auto-updater off) to the v2.9.0 auto-updating architecture without touching your chats, your login, or your settings. It backs everything up first, and it verifies the new binary on disk before removing the old one, so a failure partway leaves your existing install usable.

```bash
curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/migrate.sh -o migrate.sh
bash migrate.sh
```

Close any running `claude` sessions before you start; the script refuses to run while one is active. The full list of what it preserves is in **[Upgrading from a pinned install](install.md#upgrading-from-a-pinned-v2x-install)**.

---

## OAuth and browsers

OAuth is the browser-based login flow Claude Code uses to authenticate with Anthropic.

### Claude prints a URL but my browser doesn't open

On Android 8 (and possibly 9), copy the URL from the terminal and open it in your phone's browser (Chrome or Samsung Internet) manually. Sign in there; claude in the terminal picks up the auth state once you complete the flow. This happens whether you are on Path A (native Termux) or Path B (proot-distro Ubuntu).

This is a host-Android intent-resolution limitation, not a claude bug. In my testing, the browser auto-opened on Android 10, 13, and 17 devices but not on Android 8, so the manual paste is only needed on the older versions.

---

*Last updated: 2026-07-01.*
