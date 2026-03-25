# Changelog

## [2.3.0] - 2026-03-25

### Added

- **Cron session safety flags** -- headless `claude -p` sessions can now be locked to local-only tools using `--tools` and `--disallowedTools`. Blocks web access and network commands entirely, making scheduled autonomous sessions safe by default.
- **Custom agent loading fix documented** -- custom agents fail to load due to the same ENOENT root cause as ripgrep. Permanent fix: set `CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1` in your shell profile. Also added to the existing ENOENT entry as an alternative to the symlink.
- **Sensor API documentation** -- 9 of 11 standard Android sensor types confirmed working via NDK ASensorManager from Termux (compiled C binary, not the `termux-sensor` Java API). Accelerometer, gyroscope, magnetometer, barometer, and 5 others respond correctly. Light and proximity vary by device.
- **PulseAudio AAudio source module status** -- [PR #29074](https://github.com/termux/termux-packages/pull/29074) submitted to termux-packages for Android 16 microphone input. Replaces the broken `module-sles-source` with an AAudio-based module. Validated on all 4 architectures (aarch64, arm, i686, x86_64). Voice output via `termux-tts-speak` is unaffected.
- **SSRF guard hook** -- new `docs/ssrf-guard.md` documents a PreToolUse hook that blocks WebFetch requests to private IP ranges (127.x, 10.x, 192.168.x, etc.) and all non-HTTP/HTTPS schemes (`content://`, `file://`, `ftp://`, etc. are blocked implicitly). Prevents server-side request forgery from MCP servers or tools.
- **Agent permission matrix** -- new `docs/agent-permissions.md` documents the principle that no single agent should hold both web access and file-write permissions simultaneously (OWASP LLM06). Includes a generic permission matrix and implementation guidance.
- **Constitution template refreshed** -- three new constraints added: cron sandboxing, Termux API availability, and ADB self-connect. Native Termux documented as a viable primary environment alongside proot-distro Ubuntu.

### Changed

- **Node v25 hang resolution** -- removed hedging ("appears related to TMPDIR write permissions") from README, install.md, and troubleshooting.md. The v24 hang was specific to v24, not Termux generally. v25 resolves it.
- **Path A upgraded** -- reclassified from "Lightweight Alternative" to "Fully Viable with Node v25+." Path B (proot-distro Ubuntu) remains recommended for maximum compatibility, but Path A is no longer second-class.
- **Constitution template modernized** -- native Termux presented as a viable primary option (not just proot), `CLAUDE_CODE_TMPDIR` documented as `/tmp` alternative.
- **agents.md and story.md** -- updated runtime references to acknowledge both native Termux and proot-distro Ubuntu.

### Fixed

- **Claude Code version reference** -- removed pinned version `2.1.79` from verified config table in install.md. The native installer always fetches current; pinning a stale version is misleading.
- **Capability table row count** -- "bottom 13 rows" corrected to 12 and "top 8" corrected to 9 in adb-wireless.md (was a miscount, not a duplicate row).
- **ADB version label** -- clarified that ADB 35.x reports as version `1.0.41` in actual output.
- **Mermaid flowchart rendering** -- fixed node labels with slashes being parsed as shape syntax, which caused the decision flowchart to fail on GitHub.
- **agents.md link** -- corrected broken link.
- **EXIF metadata stripped** -- removed EXIF metadata from screenshot images.

---

## [2.2.0] - 2026-03-22

### Changed

- **Repo restructured** -- docs moved from root to `docs/` directory (install, troubleshooting, adb-wireless, agents, constitution-template, story). Community files (CONTRIBUTING, CODE_OF_CONDUCT, SECURITY) moved to `.github/`. Root now contains only README, CHANGELOG, LICENSE, VERSION, and install.sh.
- All internal links updated throughout.

### Added

- **Cron-triggered headless sessions** -- `claude -p` runs successfully from crond on Android. Enables scheduled, autonomous Claude Code sessions without a terminal open. Verified with CLAUDE.md loading correctly from the working directory.
- **Session resume** -- `claude --resume <session-id>` restores prior sessions. Session IDs visible in JSON output.
- **/compact autocompaction** -- context compaction works as expected inside running sessions.
- **Structured output** -- `--output-format json` and `stream-json` verified working on Android. Useful for scripting Claude Code into pipelines.
- **MCP server support** -- `claude mcp list` confirmed working on Android. Test device showed 5 remote servers (Cloudflare connected; Google Calendar, Gmail, Canva, Cloudinary require OAuth). Your server list depends on your Claude account integrations.

---


## [2.1.0] - 2026-03-22

### Added

- MCP remote HTTP server support verified on Android -- Cloudflare Workers tested; no local install required, works immediately after `claude mcp add`
- MCP local stdio server support verified on ARM64 -- `npx`-based servers spawn and respond correctly (tested with `@modelcontextprotocol/server-memory`)
- PDF reading support -- requires `pkg install poppler` and a `which` shim; Termux does not ship the `which` binary, which Claude Code uses to detect `pdftoppm`
- Image reading verified working -- PNG and JPG files readable via the Read tool with no additional setup
- Expanded feature test matrix -- verified on this release: MCP (both transports), PDF reading, image reading, plugins (claude-hud), hooks (all 4 types), custom skills, custom agents (6 concurrent on Opus), StatusLine API, git worktrees
- Known issues documented -- `claude doctor` crashes due to Ink raw mode stdin requirement in Termux; `process.platform === "android"` breaks code that expects `"linux"` (workaround: run inside proot-distro Ubuntu)
- Known MCP limitation documented -- OAuth flows fail in Termux terminal (no browser redirect available via `xdg-open`); remote and stdio transports are unaffected

### Fixed

- Node.js version language corrected in 3 files (CONSTITUTION-TEMPLATE.md, termux-safe skill, doctor skill) -- v25+ is confirmed working; v24 hang is historical context, not a current blocker

### Changed

- Version badge updated to 2.1.0

---

## [2.0.1] — 2026-03-21

### Security

- **Scrubbed device UIDs from test results** — `tests/results/s26ultra-android16.txt` contained real Android UID values in directory listings. Replaced with `<uid>` placeholders throughout. UIDs are not secrets but are device-specific identifiers that belong to the device owner, not the public record.
- **Sanitized `verify-claims.sh` to prevent future UID leaks** — The script now strips numeric UIDs from `ls -la` output before writing to results files. Future runs on any device will not capture owner UIDs.

### Fixed

- **Screenshot alt text corrected in README** — Updated alt text on header screenshots to match the actual device shown in each image.
- **Concurrency limit inconsistency** — STORY.md stated the historical limit of 3 (from before stress testing), CONSTITUTION-TEMPLATE.md still advised a limit of 2. Both now reflect the current tested limit of 6, consistent with CLAUDE.md and INSTALL.md.
- **Issue #16615 status in TROUBLESHOOTING.md** — The upstream issues table listed `#16615` (Platform detection — `android` not recognized) as open. Status corrected to `Closed (not planned)`.
- **Stale self-reported path in test results** — `tests/results/s26ultra-android16.txt` contained a "Results written to:" line with a device-specific absolute path. Replaced with a relative path that is valid on any clone.

---

## [2.0.0] — 2026-03-21

### Added

- **ADB wireless self-connect** — Claude Code on Android can now use ADB wireless
  debugging to connect to its own device via `adb pair/connect 127.0.0.1`. This
  unlocks system capabilities that SELinux blocks from Termux directly: `screencap`,
  `settings get/put` (including DND zen_mode), `content query` (calendar, contacts),
  `pm list packages`, `dumpsys`, `input tap/swipe/text`, `am start/force-stop`,
  `ps -A`, and `getprop`. No root required. No third-party automation app required.
  See [ADB-WIRELESS.md](docs/adb-wireless.md) for the full setup guide.

- **Agent concurrency limit raised to 6** — Stress testing with 6 simultaneous
  Claude Opus agents on mid-range Android hardware (8-core Snapdragon, 11 GB RAM)
  produced negligible load: +0.02 load average, -172 MB RAM (down, not up), +4.7°C
  temperature rise. The practical ceiling is API rate limits, not device hardware.
  Users running Claude Code agents can safely run up to 6 concurrently without thermal
  or memory concern on comparable devices. Adjust based on your hardware.

- **`CLAUDE_CODE_TMPDIR` environment variable** — An alternative to the proot bind
  mount workaround for TMPDIR. Setting `export CLAUDE_CODE_TMPDIR=/data/data/com.termux/files/home/tmp`
  (or any writable path) in your shell profile before launching Claude Code resolves
  the write-permission error without requiring proot. Documented in INSTALL.md Path A.

- **Security model documented** — Wireless debugging enabled as a permanent state
  introduces a security surface: any device on the same WiFi network can attempt ADB
  pairing. Mitigations documented: pairing code required for all new connections,
  connection is localhost-only from the Termux side, and wireless debugging can be
  toggled off when not in use. See ADB-WIRELESS.md §Security.

### Changed

- **Path B (proot-distro Ubuntu) is now the recommended path.** The primary Quick
  Start in INSTALL.md now leads with Path B. Path A (native Termux) remains fully
  documented as an alternative for users who prefer minimal setup or cannot run
  proot-distro.

- **`process.platform` behavior clarified** — Inside proot-distro Ubuntu, Claude Code
  sees `process.platform === "linux"`. In native Termux, it sees `"android"`. Many npm
  packages and tools branch on this value. Users experiencing tool failures in native
  Termux may find them resolved inside the Ubuntu guest. This is now documented
  explicitly in INSTALL.md.

- **Node v24 language softened** — The v24 hang is documented as "may hang on launch,
  likely related to TMPDIR write permissions" rather than a hard incompatibility. Users
  who have resolved TMPDIR (via bind mount or `CLAUDE_CODE_TMPDIR`) may find v24 works.
  The recommendation is still v20 LTS or the version Anthropic's installer provides.
  Node v24+ inside proot-distro Ubuntu is not subject to the same TMPDIR constraint and
  has not shown the hang behavior in testing.

### Community

- Thanks to u/Historical-Lie9697 for a detailed challenge to the proot behavior,
  Node v24 hang, and ripgrep bundled binary claims. The challenge prompted the testing
  that produced this release. All three claims were re-evaluated; the proot and ripgrep
  findings were updated, and the Node v24 language was softened accordingly.

---

## [1.2.0] — 2026-03-20

### Features

- **Path B promoted to recommended Quick Start.** README rewritten to lead with proot-distro Ubuntu — no /tmp workaround needed, native installer, cleaner environment. Path A (native Termux) presented as the lightweight alternative with a comparison table showing tradeoffs.
- **All three device screenshots in README.** S26 Ultra, Pixel 10 Pro, and S23+ screenshots displayed with captions identifying each device.
- **Images moved to `assets/` directory.** Consistent naming: `assets/screenshot-s26ultra.jpg`, `assets/screenshot-pixel10pro.jpg`, `assets/screenshot-s23plus.jpg`, `assets/logo.jpg`.
- **Remote Control section added.** Documents Anthropic's official mobile interface (launched Feb 2026) as an alternative to running Claude Code locally, with guidance on when to use each approach.
- **AVF "Paths We're Watching" section.** TROUBLESHOOTING.md now documents Android Virtualization Framework limitations (RAM allocation, NAT networking, crash data loss, Snapdragon not supported) with a contribution hook for experimenters.
- **Per-device test results structure.** `tests/results/<device>.txt` replaces the single `verification-results.txt`. `verify-claims.sh` auto-generates device-specific filenames from `getprop ro.product.model` and `ro.build.version.release`.
- **CONSTITUTION-TEMPLATE routing decision tree.** Seven-step decision tree added to help users determine which agent or tool handles a given task.
- **armhf/32-bit architecture documentation.** Budget Samsung phones (A13 and similar) ship 32-bit Android on 64-bit hardware. Claude Code requires arm64. Added architecture check to Prerequisites and a new TROUBLESHOOTING entry with affected device list and `uname -m` diagnostic.

### Bug Fixes

- **TMPDIR persistence fix in Path A Step 2.** `export TMPDIR=$PREFIX/tmp` now written to `.bashrc` inline during install, not left as a manual step.
- **Subagent EACCES note corrected.** Previous note said proot "may not fix" subagent task directory failures. Verified on device: the proot bind mount resolves EACCES for subagent task directories completely. Documentation corrected.
- **Skills link corrected.** CONTRIBUTING.md linked to `agentskills.io` (the base spec); corrected to `docs.anthropic.com` (Claude Code's own skills documentation).
- **`termux-safe` scope note added.** Skill header now states this skill applies to native Termux only, not proot-distro Ubuntu sessions.
- **Path A launch warning added.** After `npm install -g @anthropic-ai/claude-code`, users who type bare `claude` get a silent failure. Step 4 now marked Required and includes an explicit warning to use the proot launch command, not bare `claude`.
- **`install.sh` shebang fixed.** Changed from hardcoded Termux path to `#!/usr/bin/env bash` for correct behavior when inspected on non-Termux systems.
- **Orphaned Pixel screenshot deleted.** `Pixel-10-Pro-Quick-Install.png` was never referenced in any document and has been removed.
- **AVF RAM claim hedged.** Changed from "hard 4GB cap" to "~4GB default allocation" — no hard architectural limit found in AOSP docs; this appears to be a crosvm default, not a ceiling.

### Community Feedback

- **Issue templates updated.** Bug report template now includes install path (A or B), TMPDIR value, and CLAUDE_CODE_TMPDIR value as diagnostic fields. Device report template asks which path(s) were tested.
- Both armhf/32-bit and Path A launch issues were reported by real users within the first hour of going live and addressed same day.

## [1.1.0] — 2026-03-19

### Major UX Overhaul

- Added Prerequisites section with F-Droid/Termux installation walkthrough
- Added "Choose Your Path" decision point at top of INSTALL.md
- Added "What to Do First" orientation section after Quick Start
- Path B rewritten with exact verified sequence (every step tested on fresh devices)
- Device table redesigned with feature columns and "Last Verified" dates
- Three devices verified: Samsung Galaxy S26 Ultra, Google Pixel 10 Pro, Samsung Galaxy S23+
- Added `CLAUDE_CODE_TMPDIR` as documented alternative to proot
- Native installer note clarified (doesn't work in native Termux, works in Path B)

### Bug Fixes

- Fixed kernel prerequisite excluding Android 14/15 users (was 6.12.x, now varies)
- Fixed "Problem 3 is Android 16-specific" (Node v24 hang affects all ARM64)
- Aligned curl across Quick Start, INSTALL.md, and install.sh
- Stripped private repo paths from verification scripts
- Fixed `which` to `command -v` for portability
- Fixed CODE_OF_CONDUCT contact method
- Fixed install.sh shebang for desktop inspection
- Removed stale FD limit claims (~1024 → varies by device)
- Fixed duplicate EMFILE "Cause" paragraph with contradictory numbers

### Verification

- Added `tests/verify-claims.sh` — automated verification of all documentation claims
- Verification results linked from device table and INSTALL.md

## [1.0.0] — 2026-03-19

### First Stable Release

- One-command installer (`install.sh`) — installs packages, Claude Code, ripgrep fix, and shell alias in one pass
- Terminal screenshot proving Claude Code runs natively on Samsung Galaxy S26 Ultra

## [0.4.0] — 2026-03-19

### Repo Quality Pass

- Fixed false proot-distro claim in CONSTITUTION-TEMPLATE.md (was shipping wrong info to every user who copied it)
- Added "Keeping It Running" section to INSTALL.md (update, ripgrep re-fix, uninstall)
- Added shields.io badges to README (license, Android version, Node.js version, Claude Code version, last verified date)
- Populated device compatibility table with verified device (Samsung Galaxy S26 Ultra) and common devices as "untested"
- Added `disable-model-invocation: true` to `/fix-ripgrep` skill (prevents auto-invocation of a skill that installs packages)

## [0.3.0] — 2026-03-19

### Documentation Correction — proot-distro Works on Android 16

Previous documentation incorrectly stated that proot-distro was broken on Android 16 due to a "kernel-level restriction" with "no fix inside the guest distro." This was wrong.

**What actually happened:** A TCGETS2 ioctl bug in proot broke stdout in guest distros using glibc 2.41+. This was fixed in proot 5.1.107-66 (October 2025). Current proot versions (5.1.107-70+) handle guest distros correctly on kernel 6.12.

**What changed:**
- Corrected all false claims about proot-distro being broken
- Added Path B installation guide (proot-distro Ubuntu) as a valid alternative
- Documented native installer (`curl -fsSL https://claude.ai/install.sh | bash`) for Path B
- Updated TROUBLESHOOTING.md proot-distro entry with current status and upgrade instructions
- Verified: Ubuntu 25.10 installs, Claude Code 2.1.79 runs via native installer inside guest

### Two Installation Paths

Users now have a documented choice:
- **Path A (Native Termux):** 4 commands, ~2 min, lighter — recommended for most users
- **Path B (proot-distro Ubuntu):** Full Linux env, no /tmp workaround needed, native installer — for users who want a complete Linux environment

## [0.2.0] — 2026-03-18

### Skills — First Android/Termux Skills in the Ecosystem

- `/doctor` — full environment diagnostic (Node, proot, TMPDIR, ripgrep, phantom killer, storage)
- `/fix-ripgrep` — detect and fix missing arm64-android ripgrep binary (Grep/Glob ENOENT fix)
- `termux-safe` — auto-loaded constraints preventing sudo, wrong paths, silent failures

### Improvements

- Broadened support from Android 16 to Android 14+
- Added 4 new troubleshooting entries: OAuth, voice mode, ripgrep ENOENT, hooks/platform detection
- Added upstream issues table to TROUBLESHOOTING.md
- Added table of contents to TROUBLESHOOTING.md
- Fixed logo identity leak (pilgrim-logo.jpg → logo.jpg)
- Added CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md, PR template

## [0.1.0] — 2026-03-18

### Initial Public Release

- README with 4-command Quick Start
- Full step-by-step install guide (INSTALL.md)
- Troubleshooting reference with 13 entries (TROUBLESHOOTING.md)
- CLAUDE.md constitution template for Android/Termux (CONSTITUTION-TEMPLATE.md)
- Issue templates for bug reports and device compatibility
- MIT license

### Tested On
- Samsung Galaxy S26 Ultra, Android 16, kernel 6.12.x, Node.js v25.8.1
