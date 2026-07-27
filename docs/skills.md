# Skills and Scripts for Claude Code on Android

[Claude Code skills](https://code.claude.com/docs/en/skills) shipped in this repo, plus the scripts that handle deterministic checks and recoveries.

## Skills (`.claude/skills/`)

A skill is a small instruction file that teaches Claude Code how to handle a specific task. Place one under `~/.claude/skills/` (or the `.claude/skills/` of a project root) and Claude Code loads it. You use a skill by typing `/name` in Claude Code, or Claude runs it on its own when your request matches what the skill is for.

### Android / Termux

| Skill | What It Does |
|-------|-------------|
| `termux-safe` | Keeps Claude from suggesting commands that fail on Android. It knows Termux has no `sudo` and no `systemd`, that files live under `$PREFIX` (the folder Termux installs into, in place of the usual system directories), that Android limits how many background processes an app may keep, and that if you install Node.js separately, v25 or later avoids a startup hang seen on v24 (Node is not required by the install path itself). |

### Workflow (general-purpose, not Android-specific)

| Skill | What It Does |
|-------|-------------|
| `minimum-viable` | Before building anything, justify the complexity. Could a shell script do this? Does it need Node? A full app? Prevents over-engineering. |
| `scope-framing` | Before doing research, write a brief scope document. Names the decision the research serves, who acts on findings, and what counts as "done." |

## Scripts (`scripts/`)

Scripts are fixed checks and recoveries with one right answer, so they need no judgment from Claude. They are bash scripts you run directly from any shell, not skills the model invokes.

| Script | What It Does |
|--------|-------------|
| [`scripts/check-termux-env.sh`](../scripts/check-termux-env.sh) | Checks your setup and tells you what to fix: Termux:API, file-descriptor limit, process headroom, and storage. Reports PASS/WARN/FAIL for each. It detects which install you have and runs the checks that fit it. |
| [`scripts/config-validator.sh`](../scripts/config-validator.sh) | For people writing their own skills, agents, or hooks: audits a `.claude/` directory and flags problems, such as invalid `settings.json`, a hook that points at a missing script, or an agent that references a skill that is not there. |

Usage:

```bash
bash scripts/check-termux-env.sh
bash scripts/config-validator.sh        # against current working dir
bash scripts/config-validator.sh /path/to/some-repo
```

`scripts/fix-ripgrep.sh` repairs the search tool Claude Code uses to scan your files (ripgrep). Most installs never need it: on the default install Claude Code finds its bundled ripgrep on the first try. It exists as a recovery for the older and pinned installs where search can fail, and both `docs/troubleshooting.md` and `install-pinned.sh` point to it in that case.

## Installing Skills Globally

To use these skills in every project on this device, copy them to your home directory:

```bash
git clone https://github.com/ferrumclaudepilgrim/claude-code-android.git
mkdir -p ~/.claude/skills
cp -r claude-code-android/.claude/skills/* ~/.claude/skills/
ls ~/.claude/skills/
rm -rf claude-code-android   # removes only the cloned copy you just downloaded
```

The scripts under `scripts/` are independent of skill installation; just run them directly from a checkout of the repo.

---

*Last updated: 2026-07-01.*
