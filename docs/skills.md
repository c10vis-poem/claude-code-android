# Claude Code Skills for Android

Reusable [Claude Code skills](https://docs.anthropic.com/en/docs/claude-code/skills) shipped with this repo. Copy them to `~/.claude/skills/` to use in any project.

---

## Android / Termux

These skills address platform constraints specific to Termux on Android. They handle issues that do not exist on desktop.


| Skill | What It Does |
|-------|-------------|
| `/doctor` | Diagnose your full Termux + Claude Code setup in one pass (not `claude doctor`, which doesn't work in Termux) |
| `/fix-ripgrep` | Fix broken search tools (missing ARM64 Android binary) |
| `termux-safe` | Auto-loaded rules preventing `sudo`, wrong paths, silent failures |

---

## Workflow

These skills work in any Claude Code environment -- desktop, server, or mobile. They are general-purpose workflow tools included as a starting point.


| Skill | What It Does |
|-------|-------------|
| `/audience-first` | Define your audience before publishing |
| `/scope-framing` | Frame research before starting -- what decision does this serve? |
| `/config-validator` | Audit `.claude/` directory for consistency |
| `/minimum-viable` | Justify tool choices -- can a shell script do this? |
| `/search-optimized-writing` | Write docs that are findable -- error messages, searchable headings |

---

## Installing Skills

Copy them to your home directory so they work in any project:

```bash
cd ~
git clone https://github.com/ferrumclaudepilgrim/claude-code-android.git
mkdir -p ~/.claude/skills
cp -r claude-code-android/.claude/skills/* ~/.claude/skills/
ls ~/.claude/skills/
rm -rf claude-code-android   # Clean up -- phone storage is finite
```
