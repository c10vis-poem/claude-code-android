# Contributing

I maintain this project alone and use Claude Code (Anthropic's command-line AI coding assistant) as part of my own daily workflow. Contributions are welcome, but I am one person, so response times vary.

The repo is a guide plus a set of install scripts, and every claim in it is meant to be grounded on a real device I (or you) actually ran. Contributions are held to that same bar: if the scripts, the `docs/`, or a live upstream source (the Termux, Anthropic, or Node project the claim depends on) do not support a claim, it does not go in.

## Open an issue first for anything non-trivial

A typo, a broken link, or a device report can go straight to a PR or an issue. Anything that touches an install script, a documented claim, or the repo's structure: open an issue or a device report first, so we can agree on scope before you write code. It keeps you from spending an evening on a large PR I then have to decline.

## What's welcome

- Device compatibility reports, working and broken alike
- Corrections where your device contradicts what a doc says
- A troubleshooting entry for a real failure you hit and solved
- Small install-script fixes tied to a specific device or path
- Doc-clarity fixes: a step that read as confusing, a missing prerequisite
- New skills in the `.claude/skills/` format (see below)

## What's out of scope

I would rather say this plainly than decline your PR after the fact. These are more likely to be turned down, so let's talk in an issue first:

- Large feature additions or rewrites of a script's approach
- Switching the guide off its three install methods (Termux, proot-distro Ubuntu, or the Android Virtualization Framework, all defined in the [README](../README.md#quick-install)) onto a different app
- A new install path with no device proof behind it
- Marketing or hype language, or anything selling the project
- Any claim the install scripts, `docs/`, or a live upstream source do not support
- Wording-only churn that changes style without fixing an error

## Reporting bugs

Use the [bug report template](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=bug_report.yml). Before you file, check [docs/troubleshooting.md](../docs/troubleshooting.md) first: most reports fall into a handful of common issues like launch crashes, DNS hangs, search failures, and sign-in trouble on older Android versions, and each has a fix written up.

If it is not one of those, the fastest thing you can give me is:

- Device model and Android version
- `claude --version`
- Install path (A native Termux, B proot-distro Ubuntu, or C AVF)
- The exact error message
- Steps to reproduce

Node.js version (`node -v`) matters **only on Path B or a pinned install**. Native Path A ships no Node, so leave that field blank there.

## Reporting device compatibility

Use the [device report template](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.yml). For a "does it run on my phone" guide, this is the single most useful contribution, and a working report is worth just as much as a broken one. If you got Claude Code running on a device or Android version I have not tested, I want to hear it.

## Testing and verification

Verifying claims on real devices is the part I care about most. If your change touches a documented claim, run the verification suite on a real device:

```bash
bash tests/verify-claims.sh
```

It checks documented claims against your actual device and writes a file to `tests/results/`. Include that output with your PR so I can see what your hardware reported. Claims here are grounded on real devices, not on what should work in theory. If you cannot test a path, say so in the PR rather than guessing, and I will test it or hold the change until it can be verified.

If your change touches `install.sh`, `migrate.sh`, or the launcher they write, also run the automated checks. These run on every pull request, so running them first saves you a round trip:

```bash
bash scripts/check-sync.sh           # the two installers must stay identical
bash tests/wrapper-update-tests.sh   # launcher update, rollback, and preload behavior
bash tests/installer-smoke-tests.sh  # install-time launch-probe classification
bash tests/mutation-check.sh         # proves the tests fail when the code is broken
```

One thing that catches people out: `install.sh` and `migrate.sh` contain two sections that must stay byte-identical, marked with `SYNC:BEGIN` and `SYNC:END`. If you change one, make the same change in the other, or `check-sync.sh` fails the build.

## Contributing skills

Skills live under `.claude/skills/<name>/` with a `SKILL.md` carrying YAML frontmatter (this repo uses the Claude Code fields `user-invocable`, `disable-model-invocation`, and `argument-hint`; see the [skills docs](https://code.claude.com/docs/en/skills)). To add one:

1. Create `.claude/skills/<name>/` with a `SKILL.md`
2. Test it on a real Android device running Termux
3. Open a PR stating what it does and which device you tested on

Use `.claude/skills/scope-framing/` as a model for a well-formed skill. If what you want is really a deterministic check rather than a skill, `scripts/check-termux-env.sh` shows when a plain bash script is the better tool.

## AI-assisted contributions

This whole repo is about an AI coding tool, so I am not going to be weird about people using one. If AI helped you put a change together, that is fine by me. It is a big part of why more people can jump in and help at all, and I would rather have the help.

The one thing I do ask is this: if your change says something works, run it on a real device first. That is the piece I cannot check for you from here. Everything else we can sort out together in the pull request.

## PR conventions

- One focused change per PR
- Say what changed and why, which path or paths it affects, and how and on what device you tested
- Follow the [PR template](pull_request_template.md)
- If your change affects behavior or a documented claim, describe that in the PR. I handle the changelog and version updates when I cut a release, so you do not need to touch them.

## Voice and style

- Empirical-truth-first, and same-as-PC framing: the goal is helping someone run Claude Code on their phone the way they would on a PC
- Humble and specific over broad and promotional; no hype
- No em-dashes and no prose double-dashes (CLI flags and code are exempt)
- Define jargon a newcomer would not know, and do not assume the reader shares your context

## Security and conduct

Report security issues through the private advisory path in [SECURITY.md](SECURITY.md), never a public issue. Participation in this project follows the [Code of Conduct](CODE_OF_CONDUCT.md). For everyday questions, the [FAQ](../docs/faq.md) and [troubleshooting guide](../docs/troubleshooting.md) are the first stop.
