---
name: Device Compatibility Report
about: Report that Claude Code works (or doesn't) on your device
title: "[DEVICE] "
labels: compatibility
assignees: ''
---

## Device Information

- **Device model:** (e.g., Pixel 9, Galaxy S25 Ultra)
- **Android version:** (e.g., Android 15, Android 16)
- **Architecture:** (`uname -m` output)
- **Kernel version:** (output of `uname -r`)
- **Termux version/source:** (e.g., F-Droid v0.119, GitHub release)
- **Which path(s) tested:** (A: native Termux with proot bind mount, B: proot-distro Ubuntu, or both)
- **Node.js version:** (output of `node -v`)
- **Claude Code version:** (output of `claude --version`)

## Status

- [ ] Works fully
- [ ] Partial (some features broken)
- [ ] Fails to run

## Notes

Any relevant details: workarounds needed, features that don't work, proot requirements, performance observations, etc.
