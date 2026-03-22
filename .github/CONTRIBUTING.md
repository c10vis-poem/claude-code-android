# Contributing

This project is maintained by a human operator working with Claude Code as an AI development partner. Contributions are welcome, but response times vary.

## Reporting Bugs

Use the [bug report template](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=bug_report.md). Include:

- Device model and Android version
- Node.js version (`node -v`)
- Exact error message or unexpected behavior
- Steps to reproduce

## Reporting Device Compatibility

Use the [device report template](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.md). Working reports are just as useful as broken ones.

## Submitting Fixes

1. Fork the repo
2. Create a branch (`fix/description`)
3. Make your changes
4. Open a PR with your device info (model, Android version, Node version)

Keep PRs focused on a single change. Include what you tested and on what device.

## Contributing Skills

Skills live in `.claude/skills/`. Each skill has a `SKILL.md` with YAML frontmatter. To contribute a new skill:

1. Create a directory under `.claude/skills/<skill-name>/`
2. Add a `SKILL.md` following the [Claude Code skills format](https://docs.anthropic.com/en/docs/claude-code/skills). Note: Claude Code extends the base Agent Skills spec with fields like `user-invocable`, `disable-model-invocation`, and `argument-hint`
3. Test it on a real Android/Termux device
4. Open a PR with what it does and what device you tested on
