# Contributing

I maintain this project and use Claude Code (Anthropic's command-line AI coding assistant) as part of my workflow. Contributions are welcome, but response times vary.

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
4. Open a PR with your device info (model, Android version, Node version). The PR template will guide you through the required information.

Keep PRs focused on a single change. Include what you tested and on what device.

## Contributing Skills

Skills live in `.claude/skills/`. Each skill has a `SKILL.md` with YAML frontmatter. To contribute a new skill:

1. Create a directory under `.claude/skills/<skill-name>/`
2. Add a `SKILL.md` following the [Claude Code skills format](https://code.claude.com/docs/en/skills). The skills in this repo use Claude Code-specific frontmatter fields including `user-invocable`, `disable-model-invocation`, and `argument-hint`
3. Test it on a real Android device running Termux (the terminal-emulator app this guide is built around)
4. Open a PR with what it does and what device you tested on

## Testing

Before submitting a PR that changes documentation claims, run the verification suite:

```bash
bash tests/verify-claims.sh
```

This tests documented claims against your actual device. Submit the output file (saved to `tests/results/`) alongside your PR so I can see your device's results.

See `.claude/skills/scope-framing/` for an example of a well-structured skill with YAML frontmatter, or `scripts/check-termux-env.sh` for an example of a deterministic check that lives as a bash script rather than a skill.
