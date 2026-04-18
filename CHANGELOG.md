# Changelog

## [2.6.0] - 2026-04-18

Documentation refresh plus security hardening. Corrects stale claims, migrates docs URLs following Anthropic's domain move, updates Path A install instructions for upstream npm package restructure, corrects the hooks-on-Termux section to reflect current behavior, adds an audio-backend section covering `/voice` mode on vendor-broken devices, and adds an Android 17 Beta status note to the AVF guide. Rewrites `examples/ssrf-guard.sh` to close real bypasses in the previous regex-based implementation, adds a 47-case test harness, and adds `.gitattributes` so shell scripts stay LF on Windows checkouts (CRLF breaks them on Termux).

### Fixed
- OWASP LLM Top 10 citation in `docs/agent-permissions.md` (Excessive Agency is LLM08, not LLM06)
- Anthropic pricing URL in README migrated from `anthropic.com/pricing` to `claude.com/pricing`
- Uncited "approximately 1-2%" prompt injection rate removed from `docs/security-model.md`; replaced with "non-zero risk" framing
- `dd` benchmark in `docs/avf-guide.md` qualified to note that the read figure includes page cache and overstates real disk throughput
- Claude Code version reference refreshed in `.claude/skills/doctor/SKILL.md` example output
- Hooks-on-Termux section in `docs/troubleshooting.md` corrected. Earlier wording stated PreToolUse/PostToolUse hooks did not fire on `process.platform === "android"`; that is no longer accurate. Replaced with concrete debugging steps. Reference to upstream issue #16615 retained as historical context.
- **`examples/ssrf-guard.sh` rewritten to close real bypasses.** The previous regex-based IPv4 check required four dotted octets, so short-form IPs (`http://127.1/`) and mixed-format IPs (decimal `2130706433`, hex `0x7f000001`) passed through to loopback. A prompt-injected WebFetch call using any of those forms would reach internal services. The rewrite offloads URL parsing to Node's `new URL()` — the same RFC 3986 normalization Claude Code's WebFetch uses internally — then applies private-range checks on the normalized hostname. Covers short-form IPv4, decimal, hex, IPv4-mapped IPv6, cloud metadata aliases, case-sensitive hostnames, and malformed URLs. WebSearch bare queries (no `://`) now pass through instead of being blocked as missing-scheme. DNS-rebinding limitation remains and is documented in the header.
- Subscription tier list in README and `docs/install.md` expanded from "Pro or Max" to match upstream's documented list (Pro, Max, Team, Enterprise, or Console/API account).
- `docs/install.md` softened "preferred installation method" to "recommended installation method" to match upstream wording exactly.

### Changed
- All Anthropic Claude Code docs URLs migrated from `docs.anthropic.com/en/docs/claude-code/*` to `code.claude.com/docs/en/*` (Anthropic moved the docs domain). Affects README.md, `.github/CONTRIBUTING.md`, `docs/agent-permissions.md`, `docs/skills.md`.
- Path A install method updated to route Claude Code through the `cli-wrapper.cjs` JavaScript fallback. Anthropic restructured the `@anthropic-ai/claude-code` npm package so the CLI is delivered via platform-specific optional native binaries; android-arm64 is not in that distribution list. The install completes but bare `claude` errors with "claude native binary not installed." The same package ships `cli-wrapper.cjs`, a JavaScript fallback launcher; invoking it through Node works on android-arm64. The existing proot tmp wrapper is retained. Affects README, `install.sh`, `docs/install.md`.
- README intro updated from "two ways" to "three ways" to reflect Path C/AVF documentation already present.
- Footer dates refreshed on `docs/install.md`, `docs/security-model.md`, `docs/avf-guide.md`.
- README "Last Verified" badge updated to `2026-04-18`; Version badge updated to `2.6.0`.

### Added
- New README section "Audio: /voice mode and the chain underneath" documenting the SoX → PulseAudio → backend → mic chain. Identifies vendor-device failures at the SLES backend layer (termux/termux-packages#28861, termux/termux-packages#27978, termux/termux-packages#27367, termux/termux-packages#26871) and points to termux/termux-packages#29319 (Oboe package + PulseAudio Oboe modules) as the fix path. Includes the user opt-in steps for after the PR lands. Caveat noted that Claude Code's own SoX detection on Termux is a separate concern.
- Android 17 Beta status note at the top of `docs/avf-guide.md`. Existing Android 16 content retained as baseline reference; A17 Beta not re-verified end-to-end in this cycle.
- `tests/ssrf-guard-tests.sh` — 47-case test harness for the SSRF guard. Feeds JSON PreToolUse payloads covering short-form IPs, private ranges, cloud metadata, IPv6 forms, bad schemes, WebSearch queries, and edge cases. Used to prove the previous guard had real bypasses and that the rewrite closes them.
- `.gitattributes` pinning `*.sh` to LF line endings. Windows checkouts would otherwise get CRLF, which breaks the scripts when they land on Termux (bash errors on `$'\r'` at end of lines).

### Notes
- Path A cli-wrapper.cjs workaround verified on a current Termux install where Claude Code is actively running through it.
- Path B (proot-distro Ubuntu + official curl|bash installer) documentation not freshly re-verified end-to-end in this update; matches Anthropic's current upstream guidance for linux-arm64.
- Per-device verification dates in the README compatibility table left unchanged; individual devices not re-tested in this cycle.
- SSRF guard rewrite tested on-device with 47 test cases; all pass. Previous implementation failed 7. Test harness at `tests/ssrf-guard-tests.sh` verifies this.

## [2.5.1] - 2026-04-03

### Added
- **Security model document** (`docs/security-model.md`) -- centralized threat model covering Termux:API permission exposure, ADB capability escalation, the critical difference between app-level and shell-level access, threat scenarios in plain language, existing mitigations, and a minimal-risk setup checklist
- **README security notice** -- visible before Prerequisites, links to security model
- **Termux:API permission scoping guidance** in install guide -- only grant the permissions your workflow requires
- **Download-then-inspect alternative** in install guide Path B -- inspect the install script before running it
- **shellcheck CI workflow** -- runs on push and PR for install.sh and verify-claims.sh
- **Markdown link checker CI workflow** -- checks for broken links across all documentation
- **Executable hook examples** -- `examples/ssrf-guard.sh` and `examples/fingerprint-gate.sh` adapted from documentation into standalone runnable files

### Changed
- **ADB capabilities table** -- added risk/exposure column so capabilities include security context
- **SSRF guard and fingerprint gate docs** -- reference examples/ files as canonical script location
- **Skills documentation** -- Android-specific and general-purpose workflow skills separated with descriptive intros
- **README navigation bar** -- added Security Model link
- **Version badge** updated to 2.5.1

### Security
- Security audit found users could complete installation and grant full device access (SMS, contacts, GPS, camera, screen capture, input injection) without encountering a security warning. This release adds the security model, README warning, permission scoping guidance, and risk context to the ADB capabilities table.


## [2.5.0] - 2026-04-02

### Added
- **Path C -- AVF (Android Virtualization Framework)** documented as experimental third installation path. Claude Code installed and used for real work inside an AVF VM on a Pixel 10 Pro (Android 16). Full setup checklist, VM configuration, ADB hardware bridge, security defaults, and three-path comparison included. See `docs/avf-guide.md`.
- VM configuration section documenting writable `vm_config.json` with configurable RAM (`memory_mib`), memory balloon control (`auto_memory_balloon`), and boot timeout
- ADB wireless debugging from inside the VM documented with pairing workflow, port scanning, split-screen pairing tip, and screen-off stability commands (semi-fix)
- ADB hardware bridge section: 42 sensors enumerable, GPS coordinates accessible, camera launchable with viewfinder capture, screenshots and screen recording, input injection (tap/swipe/text), battery state, WiFi info, plus command reference
- Security defaults section covering default passwords, SSH config, firewall state, shared storage SSH key exposure, and hardening suggestions
- Technical details appendix: virtual hardware inventory (15 virtio devices), kernel config findings (CONFIG_SYSVIPC disabled, BPF/FUSE/OverlayFS enabled), running services (7 AVF-specific), crosvm launch parameters
- AVF section added to README Quick Start with inline setup commands, key capabilities, and limitations summary
- Three-path comparison table in README (Path A / Path B / Path C) replacing the two-path table, including RAM, ADB hardware bridge, and audio columns
- Path C column added to device compatibility table
- Community resources section in AVF guide: 10 curated links covering memory fixes, GPU status, setup guides, bug filing, and Snapdragon alternatives
- Navigation bar updated with AVF guide link

### Changed
- Troubleshooting "Paths We're Watching" section upgraded from "Not Recommended Yet" to "Experimental, Tested on Pixel" with verified capabilities, known issues, and security notes
- Known issues table expanded with: `apt upgrade` hang on TUI dialogs, SysV IPC disabled, nftables non-functional, Terminal Activity recreation, VM IP rotation, GPU acceleration limited to Pixel 10
- Version badge updated to 2.5.0
- Last verified badge updated to April 2026
- Device compatibility table expanded with Path C column

### Community
- AVF testing performed on a single Pixel 10 Pro. All findings framed as observations from our test device, not universal claims. Google's AVF documentation remains extremely limited -- most capabilities and limitations were discovered empirically. Screen-off stability improved with ADB hardening but remains a semi-fix. Copy-paste reliability in the Terminal app remains the largest UX friction point.

## [2.4.0] - 2026-03-28

### Added
- Termux:API elevated to required dependency with source-matching warning (F-Droid+F-Droid or GitHub+GitHub)
- Fingerprint biometric gate documentation for securing sensitive operations
- Vendor-specific Samsung sensor types documented (elevator detector, back tap, car crash detect, pocket mode, drop classifier)
- install.sh: architecture check (aarch64 required), pkg update before install, termux-api package
- CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1 documented as durable ripgrep fix (survives updates)
- "From the developer" tip at top of README
- Third device screenshot (Samsung Galaxy S23+)
- Session persistence note (crond, Termux:Boot, shell scripts)
- Cron proot wrapper note for Path A users
- 8 new test claims in verify-claims.sh (cron, sensors, SSRF, agent permissions, Termux:API, xdg-open, fingerprint, architecture)
- Supported versions table in SECURITY.md
- verify-claims.sh reference in CONTRIBUTING.md
- Issue template chooser (config.yml disables blank issues)
- docs/skills.md created (workflow skills moved from README)

### Changed
- ADB capability table: process inspection corrected from "Blocked" to "Termux processes only"
- MCP section: corrected xdg-open claim (exists as symlink to termux-open; OAuth localhost redirects still fail)
- Time estimates qualified with "(experienced)" across all installation paths
- "Why This Is Hard" section condensed from 4 subsections to 5 bullet points
- Path B "Most users should start here" callout added
- Security warning moved from README top to ADB section (contextually appropriate)
- Agent roster replaced with summary + link to docs/agents.md
- Workflow skills moved to docs/skills.md, README keeps Android skills only
- "Our Story" link removed from top navigation bar
- Known Constraints "No systemd" row expanded with crond, Termux:Boot, termux-job-scheduler
- /doctor skill disambiguated from built-in `claude doctor` command
- termux-safe skill: "No apt" corrected to "Prefer pkg over apt"
- README reduced from 416 to ~382 lines

### Fixed
- install.sh: missing pkg update before package install
- Calendar query example in ADB docs (projection delimiter, shell escaping)
- Screenshot file extension mismatch (pixel10pro was PNG with .jpg extension)
- verify-claims.sh FD limit test no longer hardcodes ~1024
- PR #31701 status updated to "Closed (not merged)" in upstream issues table
- Troubleshooting count updated from "17+" to "20+"

### Community
- AAudio source module PR (termux-packages#29074) -- adds module-aaudio-source.c to PulseAudio, enabling microphone input via AAudio on Android 12+ where OpenSL ES input was removed. Approved by robertkirkman, hardware-tested on 32-bit ARM Android 8 and 64-bit ARM Android 13. Awaiting maintainer merge.
- CUPS fix PR (termux-packages#29123) -- fixes three bugs making CUPS nonfunctional on fresh Termux installs: (1) web UI returns 403 on static assets because package builder strips world-read permissions, (2) Add Printer crashes cupsd due to missing spool directory, (3) policy engine denies admin operations because SystemGroup directive was removed. Approved by TomJo2000. Awaiting maintainer merge.

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
