# FAQ

Common questions and gotchas for Claude Code on Android.

---

## Installation

### "Unsafe app blocked" when installing the Termux APK

On Android 11 and newer, Google Play Protect flags the F-Droid Termux APK (which targets SDK 28) as "built for an older version of Android." This is a Play Protect warning, not a real safety issue: the APK is signed by Termux's maintainers and works correctly.

To proceed:

1. Tap **More details** in the dialog
2. Tap **Install anyway**

Or install Termux through the F-Droid app instead of side-loading the APK directly. The F-Droid app handles this dialog inline.

### install.sh hangs or fails with "Failed to fetch"

Termux's `pkg update` picks a mirror automatically from a list of about 18 candidates worldwide. The picker is weighted by reachability, but the result is non-deterministic: a fresh Termux on the same device can pick different mirrors on different days. Some mirrors are slow or temporarily unreachable from your network, which can hang `pkg update` or `pkg install` for 10+ minutes before erroring out.

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

- **Y** or **I** -- install the package maintainer's new version (overwrites your local changes)
- **N** or **O** -- keep your old (current) version (this is the default)
- **D** -- show the diff between your version and the new one
- **Z** -- drop to a shell so you can investigate before deciding

Two letters per choice are historical: `Y/N` is the common convention; `I/O` ("Install" / "Old") was the older dpkg convention. Both still work.

To handle this non-interactively and keep all local config files unchanged:

```bash
DEBIAN_FRONTEND=noninteractive pkg upgrade -y -o Dpkg::Options::="--force-confold"
```

### Which packages should I install after `install.sh`?

`install.sh` is bare-minimum -- only `nodejs` and Claude Code itself. Vanilla Termux gives you `rg`, `curl`, `unzip`, `tar`, `gzip`, `less`, `nano` already. Everything else Claude Code typically reaches for (`git`, `gh`, `jq`, `python`, `openssh`, `tree`, `clang`, `htop`, etc.) is not present. See **[Recommended Common Packages](install.md#recommended-common-packages)** in install.md for the one-liner that adds what's commonly needed and prevents recurring tool failures.

---

## Choosing a path

### Which path should I use?

| If you want | Pick |
|---|---|
| The smallest install (Termux core + a few packages) | Path A (native Termux) |
| The latest Claude Code features | Path B (proot-Ubuntu, ~1-2 GB rootfs; native binary, no Node required) |
| To avoid managing a version pin | Path B |
| Fastest first-launch | Path A (Path B carries a proot-distro startup cost) |

Both paths are tested and supported. Path A is the lighter footprint with a version pin; Path B is the heavier footprint that gets you upstream-latest claude.

### Why does Path B install a newer claude than Path A?

Path A installs via `npm install -g` in native Termux, which links against **bionic** (Android's libc). Anthropic's claude-code binary for android-arm64-bionic was removed in 2.1.113 (see [#50270](https://github.com/anthropics/claude-code/issues/50270)). Path A therefore pins to 2.1.112, the last version that still has a working android-arm64 build.

Path B installs claude inside a proot-Ubuntu environment, which uses **glibc** (standard Linux libc). Anthropic's install.sh inside Ubuntu pulls the linux-arm64 binary (matching your CPU). This binary is current and unaffected by the android-arm64-bionic issue. As of 2026-05-16, Path B installs claude 2.1.143 cleanly.

Net effect: same `claude` tool, different binaries, different versions, both work.

---

## OAuth and browsers

### Claude prints a URL but my browser doesn't open

On Android 8 (and possibly 9), claude cannot auto-open a browser when triggering OAuth -- regardless of whether you are on Path A (native Termux) or Path B (proot-Ubuntu). The URL is printed to the terminal; copy it and paste it into your phone's browser manually.

This is a host-Android intent-resolution limitation, not a claude bug. Verified empirically on 2026-05-16:

- Android 17 (Pixel 10 Pro), Android 13 (Pixel 6), Android 10 (Moto G7 Power): browser auto-opens to Chrome
- Android 8 (Galaxy S7): browser does NOT auto-open

If you're on Android 8 or 9, copy the URL from the terminal output and open it in Chrome or Samsung Internet manually. Sign in there; claude in the terminal will pick up the auth state once you complete the flow.

---

*Last updated: 2026-05-16.*
