# Agent Permission Separation

A guide to structuring AI agent permissions so that no single agent holds both web access and file-write access simultaneously.

---

## The Principle

When an AI agent can both fetch content from the internet and write to local files, it creates a direct path from untrusted external content to your filesystem. This is the core risk behind OWASP LLM06 (Excessive Agency) -- an agent that can read a malicious web page and then write to your project files can be manipulated into executing prompt injections, writing malware, or exfiltrating data.

The fix is structural: **separate web access from write access across different agents.**

---

## Permission Matrix

A minimal agent setup with permission separation:

| Agent | Read Files | Write Files | Web Access | Shell (Bash) | Notes |
|-------|-----------|-------------|------------|--------------|-------|
| Research Agent | Yes | No | Yes | No | Fetches and summarizes external content. Cannot modify local files. |
| Code Agent | Yes | Yes | No | Yes | Builds, edits, and tests code. Cannot reach the internet. |
| Review Agent | Yes | No | No | No | Read-only analysis. Audits code, checks for issues. |
| Docs Agent | Yes | Yes | No | No | Writes documentation. No shell, no web. |
| Automation Agent | Yes | Yes | No | Yes (restricted) | Runs builds and tests. Shell access limited to specific commands. |

**Key constraint:** No single row has both "Write Files: Yes" and "Web Access: Yes."

---

## Why This Matters

### Without separation

A single all-access agent:

1. Receives a task: "Research best practices for X and update our config"
2. Fetches a web page that contains a prompt injection in hidden text
3. The injection tells it to write a backdoor into the config file
4. The agent complies -- it has both web access and write access

### With separation

Two agents, separated:

1. Research Agent fetches the web page and extracts information
2. Research Agent returns a summary (text only, no file writes)
3. Code Agent receives the summary and updates the config
4. The prompt injection in the web page never reaches an agent that can write files

The separation does not make prompt injection impossible -- it makes the attack path require compromising two agents instead of one, and the handoff between them is a natural inspection point.

---

## Implementation in Claude Code

Claude Code's `--tools` and `--disallowedTools` flags control which tools an agent can use:

```bash
# Research agent: can fetch web content, cannot write files
claude -p "Research X" \
  --tools "Read,Glob,Grep,WebFetch,WebSearch" \
  --disallowedTools "Write,Edit,Bash"

# Code agent: can write files, cannot access web
claude -p "Update the config based on this research: ..." \
  --tools "Read,Write,Edit,Bash,Glob,Grep" \
  --disallowedTools "WebFetch,WebSearch"
```

For subagents defined in `.claude/agents/`, embed tool restrictions in the agent prompt:

```markdown
## Tools

You may use: Read, Glob, Grep, WebFetch, WebSearch
You may NOT use: Write, Edit, Bash

You are a research agent. You find information and return it as text.
You do not modify any files.
```

### Restricting Bash network access

An agent with Bash access can bypass web tool restrictions using `curl` or `wget`. To close this gap:

```bash
--disallowedTools "WebFetch,WebSearch,Bash(curl:*),Bash(wget:*)"
```

This removes the web tools and blocks `curl` and `wget` from Bash, while leaving other Bash commands available.

---

## Cron and Headless Sessions

Scheduled sessions deserve extra scrutiny because no human is watching. A cron job should use the most restrictive tool set possible:

```bash
claude -p "your prompt" \
  --tools "Read,Write,Edit,Bash,Glob,Grep" \
  --disallowedTools "WebFetch,WebSearch,Bash(curl:*),Bash(wget:*)"
```

This gives the session full local capability but zero network access. If a cron job needs web access, it should not be a cron job -- it should be an interactive session where a human can review what comes back.

---

## Limitations

- **Tool restrictions are advisory in agent prompts.** Claude Code respects `--tools` and `--disallowedTools` flags at the CLI level, but agent prompt instructions ("you may not use Write") rely on the model following instructions. The CLI flags are the hard boundary.
- **Indirect writes.** An agent with Bash access can write files via shell commands even without the Write tool. Restrict Bash access for agents that should be read-only.
- **Context window transfer.** When a research agent's output is passed to a code agent, any prompt injection in the research output is now in the code agent's context. The separation reduces risk but does not eliminate it -- the code agent still processes the text.

---

## Further Reading

- [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/) -- LLM08: Excessive Agency
- [Claude Code tool permissions](https://code.claude.com/docs/en/cli-usage) -- `--tools` and `--disallowedTools` flags

---

*This guidance applies to any AI agent system, not just Claude Code. The principle is universal: separate the ability to read untrusted content from the ability to modify trusted files.*
