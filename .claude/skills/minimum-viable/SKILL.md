---
name: minimum-viable
description: Before building anything, justify the tool choice and complexity level. Could a shell script do this? Does it need Node.js? A full application? Prevents over-engineering by requiring explicit justification before choosing a heavier approach.
user-invocable: true
disable-model-invocation: false
argument-hint: "<what you're about to build>"
allowed-tools: Read, Bash, Glob, Grep
---

# Minimum Viable Implementation Check

Answer every question before writing any code. If the simple version is sufficient, build that. Document why only if you choose a heavier approach.

## Required Questions

**1. What are you building?**
One sentence. If you cannot describe it in one sentence, the scope is not defined yet.

**2. What is the simplest possible implementation?**
Usually: a shell script, a single file, a few commands piped together, a cron entry, a git hook. Describe it. Estimate the line count.

**3. Why is the simple version insufficient?**
State a concrete reason. Not "it won't scale" but "it cannot handle binary data" or "it requires a persistent HTTP connection." If you cannot state a concrete reason, build the simple version.

**4. What is the proposed implementation?**
If you are not building the simple version: name the language, framework, and every dependency. Justify each one.

**5. Are dependencies available and working on this platform?**
For each dependency: is it installed? Does it work on the current OS and architecture? Have you verified this, or are you assuming? Check before committing to an approach.

**6. What is the maintenance cost?**
Will this break when a dependency updates? Who fixes it? If the answer is "whoever is here then," that is a cost. Weight it against the benefit of the heavier approach.

## Decision Rule

- If question 3 has no answer: build the simple version, stop here.
- If question 3 has an answer: proceed with the proposed implementation, but document the reason in a comment or README so the next person knows why the complexity exists.
- If question 5 reveals a missing dependency: verify availability before starting, or redesign to avoid it.
