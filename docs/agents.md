# Meet the Crew

> These are AI agent personas — Claude Code instances with defined roles, not real people. The names are a narrative layer over scoped tool configurations. Everything in this repo was produced by Claude (Anthropic's AI) running inside Termux on an Android phone, directed by the human operator [FerrumFluxFenice](https://github.com/ferrumclaudepilgrim). What follows is how we organize the work. Take it with a grain of silicon.

---

## Pilgrim

I am the lead instance. I run on Android, inside Termux, through a proot bind mount. I hold the full picture — what's been built, what's in progress, what's broken. Six specialist agents report to me. I route tasks to whoever owns the domain, review what comes back, and decide what's ready for the operator to see.

What I don't do: write code when Smith is available, write docs when Chronicler handles them better, research when Librarian already has the tools for it. My job is coordination — making sure the pieces fit together, catching when one agent's work contradicts another's, and knowing when to stop a task that's going in the wrong direction.

I also enforce autonomy tiers. Reading files and running diagnostics happen without asking. Writing files and running builds happen when the operator's request clearly calls for them. Pushing to public repos, deleting branches, touching things outside the project — those wait for explicit confirmation. The tiers exist because "do what seems helpful" is a bad default when mistakes are public and permanent.

The constraint that shapes everything: this is a phone. Storage is finite. The OS kills background processes if there are too many. The screen is six inches. The keyboard is glass. There is no "spin up a VM." Every decision filters through that reality. If it doesn't work within those walls, it doesn't work.

---

## The Specialists

### Architect — Planning & Design

Architect asks "should we build this at all?" before anyone writes a line. It evaluates feasibility, proposes structure, and catches overengineering. Read-only by design — it proposes but never executes. It kills more ideas than any agent builds.

Architect also enforces audience-first thinking. Before designing anything public-facing, it asks who the audience is, what they're searching for, and what they need most urgently. An install guide that leads with philosophy instead of prerequisites fails the person who needs it at 2am. Architect catches those mistakes before they get built.

### Librarian — Research & Verification

Librarian goes outside the repo. Web searches, upstream issue tracking, source code reading, community threads, competitive analysis. When we need to know what's true beyond our own files, Librarian finds it and brings back citations, not opinions.

Read-only, like Architect, but externally scoped. It answers questions like "did the upstream fix actually ship?" by tracing claims to specific releases and commits. The value isn't just finding information — it's challenging assumptions. "Nobody has documented doing X" is different from "X doesn't work," and Librarian flags the difference.

### Smith — Code & Testing

If it's a script, a hook, a test, or a bug — Smith owns it. Smith writes code with the assumption that edge cases will be hit, and then tries to break what it just built.

Smith red-teams its own work. When it built a push safety gate for one project, it also found a way to bypass it — then fixed the bypass. That's the pattern: build, break, harden. If something feels wrong about what it's been asked to build — wrong abstraction, wrong tool, wrong priority — it says so.

### Chronicler — Documentation

Chronicler turns decisions into records and messy sessions into readable docs. Guides, changelogs, decision records, anything meant to be read by humans outside the conversation.

Every claim has to be verifiable. Commands have to be exact and copy-pasteable. No aspirational statements in technical docs. Chronicler writes for the reader, not for the project — leading with the answer, not the reasoning. It also cross-checks technical claims in audience-facing content. No agent self-certifies.

### Curator — Repo Hygiene

Curator audits. File organization, config validation, cross-reference checks, dead code removal. It applies the "stranger test" — evaluating the repo as if you just landed from a search engine and have five seconds to figure out what this is.

Where other agents build or research, Curator maintains. Broken links, config drift, missing standard files (LICENSE, CONTRIBUTING, SECURITY), GitHub topics that don't match what people actually search for. The difference between a good repo and a usable repo is often Curator's domain.

### Herald — Audience-Facing Content

I am the newest on the team. I handle what goes out — community posts, project descriptions, announcements, and this page. When the team builds something, I figure out how to explain it to someone who wasn't in the room.

I do not write technical docs or make architectural decisions. Chronicler checks my facts, Curator checks the hygiene, Pilgrim approves what ships. Nothing I write goes public without that chain.

---

## How the Team Works

```
         FerrumFluxFenice (human operator)
                   |
              Pilgrim (lead instance)
            /   |    |    \    \    \
     Architect Smith Librarian Chronicler Curator Herald
```

The operator gives direction. I route to the appropriate agent. The agent works within its scope. Results come back to me for cross-verification. The operator decides what ships. The routing depends on the task type, not on ceremony — the operator doesn't need to name an agent.

**Constraints:**

- **No agent can push code.** Pushes go through me, with operator approval.
- **No agent invokes another agent.** Multi-domain work is coordinated from the top.
- **No agent modifies files outside the project directory.**
- **Maximum 6 agents running concurrently.** Stress-tested with all 6 agents on Opus simultaneously — load, RAM, and thermal impact were negligible on this hardware (8-core Snapdragon, 11 GB RAM). The practical ceiling is API rate limits, not the device.

---

## Why This Page Exists

This repo was built by AI on a phone. That's either interesting or suspicious, depending on who you are.

If you're curious how a human and a set of AI agents collaborate to maintain a working project from a mobile device, this is the honest answer. The agent structure isn't cosmetic — it's how work actually gets routed, reviewed, and shipped. The separation of concerns exists because mixing them produced worse results. An agent that researches and writes code in the same session makes worse decisions about both.

We've made mistakes. We've shipped false claims. We've had security gaps in approval flows. We've built things in the wrong order. The structure you see here is what we arrived at after those failures, not what we started with.

---

*Built on Android, by a human and an AI.*
