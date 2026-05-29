# Skills and Scripts for Claude Code on Android

[Claude Code skills](https://code.claude.com/docs/en/skills) shipped in this repo, plus the scripts that handle deterministic checks and recoveries.

## Skills (`.claude/skills/`)

Skills are loaded by Claude Code when you place them under `~/.claude/skills/` (or the `.claude/skills/` of a project root). They appear as slash commands and can be invoked by the model when context matches the skill's description.

### Android / Termux

| Skill | What It Does |
|-------|-------------|
| `termux-safe` | Termux constraints: no sudo, no systemd, paths under `$PREFIX`, phantom-process-killer ceiling, and a note that if Node.js is installed separately, v25+ avoids the historical v24 startup hang (Node is not required by the install path itself). |

### Workflow (general-purpose, not Android-specific)

| Skill | What It Does |
|-------|-------------|
| `minimum-viable` | Before building anything, justify the complexity. Could a shell script do this? Does it need Node? A full app? Prevents over-engineering. |
| `scope-framing` | Before doing research, write a brief scope document. Names the decision the research serves, who acts on findings, and what counts as "done." |

## Scripts (`scripts/`)

Scripts are deterministic checks and recoveries. They are bash scripts you run directly, not skills the model invokes. The previous `/doctor`, `/fix-ripgrep`, and `/config-validator` skills were deterministic in shape (no LLM judgment required); they live here as scripts you can run from any shell.

| Script | What It Does |
|--------|-------------|
| [`scripts/check-termux-env.sh`](../scripts/check-termux-env.sh) | Run environment checks: Termux:API, file-descriptor limit, process headroom, storage. Reports PASS/WARN/FAIL with fix recommendations. Renamed from the `doctor` skill to avoid collision with the upstream `claude doctor` command. Auto-detects v2.9.0 vs v2.x install layouts via filesystem signals and runs the appropriate set of checks. |
| [`scripts/config-validator.sh`](../scripts/config-validator.sh) | Audit a `.claude/` directory: frontmatter fidelity, file/dir naming, settings.json JSON validity, hook script existence, agent → skill cross-references. Useful after adding new agents, skills, or hooks. |

Usage:

```bash
bash scripts/check-termux-env.sh
bash scripts/config-validator.sh        # against current working dir
bash scripts/config-validator.sh /path/to/some-repo
```

`scripts/fix-ripgrep.sh` is retained in the repo for users still on a v2.x install; it is not needed under v2.9.0 and is not referenced from user-facing instructions.

## Installing Skills Globally

To use these skills in every project on this device, copy them to your home directory:

```bash
git clone https://github.com/ferrumclaudepilgrim/claude-code-android.git
mkdir -p ~/.claude/skills
cp -r claude-code-android/.claude/skills/* ~/.claude/skills/
ls ~/.claude/skills/
rm -rf claude-code-android   # clean up; phone storage is finite
```

The scripts under `scripts/` are independent of skill installation; just run them directly from a checkout of the repo.

---

*Last updated: 2026-05-29.*
