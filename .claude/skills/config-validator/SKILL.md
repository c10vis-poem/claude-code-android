---
name: config-validator
description: Validate .claude/ configuration for consistency: agent definitions, skill files, hook registrations, settings.json, and tool grants. Use during repo audits or after adding new agents, skills, or hooks.
user-invocable: true
disable-model-invocation: false
argument-hint: "(no arguments needed)"
allowed-tools: Read, Bash, Glob, Grep
---

# Config Validator

Run every check below against the `.claude/` directory in the current repo. Report results as a table at the end.

## Checks

**1. Agent files (.claude/agents/)**
- Does each `.md` file have frontmatter with `name` and `description`?
- Does the `name` field match the filename (without extension)?
- Do `disallowedTools` entries use valid tool names?
- Does the `skills` field (if present) list only skills that exist in `.claude/skills/`?

```bash
ls .claude/agents/ 2>/dev/null || echo "NO AGENTS DIR"
```

**2. Skill files (.claude/skills/)**
- Does each skill directory contain a `SKILL.md`?
- Does each `SKILL.md` have frontmatter with `name`, `description`, and `user-invocable`?
- Does the `name` field match the directory name?
- Are `allowed-tools` values valid tool names?

```bash
ls .claude/skills/ 2>/dev/null || echo "NO SKILLS DIR"
```

**3. Hook registrations (.claude/settings.json)**
- Does `settings.json` exist and parse as valid JSON?
- For each hook registered: does the referenced script file exist on disk?
- Are hook matchers valid regex or glob patterns?
- Are timeouts present and reasonable (under 30 seconds for most hooks)?

```bash
cat .claude/settings.json 2>/dev/null || echo "NO SETTINGS FILE"
```

**4. Cross-references**
- Do any agents reference skills that do not exist in `.claude/skills/`?
- Do any hooks reference scripts that are not present?
- Are there orphaned skill directories with no `SKILL.md`?
- Are there scripts in hook directories not registered in `settings.json`?

**5. Naming consistency**
- Are all directory and file names kebab-case?
- Do frontmatter `name` fields match their directory or filename exactly?

## Output Format

```
| Component | Check | Status | Detail |
|-----------|-------|--------|--------|
| agents/my-agent.md | name matches filename | PASS | |
| skills/my-skill | SKILL.md present | FAIL | directory exists, no SKILL.md |
| settings.json | hook script exists | WARN | hooks/pre-commit.sh not found |
```

After the table, list every FAIL with the specific fix required. List WARN items separately. If everything passes, say so.
