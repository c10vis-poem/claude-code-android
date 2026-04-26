---
name: audience-first
description: Before finalizing any public-facing design, document, or feature, identify the audience, what they search for, and what they need most urgently. Use when creating README sections, naming repos, writing descriptions, or designing user-facing interfaces.
user-invocable: true
disable-model-invocation: false
argument-hint: "<what you're about to create or publish>"
allowed-tools: Read, Bash, Glob, Grep
---

# Audience-First Checklist

Complete every question below before finalizing any public-facing work. Do not skip items because they seem obvious; the obvious answers are usually wrong.

## Required Questions

**1. Who is the audience?**
Be specific. Not "developers" but "developers who just hit error X and are searching for a fix right now." Name the frustration, the skill level, the context. If there are multiple audiences, rank them and address the primary one first.

**2. What would they search for?**
List exact search terms: the strings they would type into Google or GitHub search. Not what you would search for, but what someone encountering this problem for the first time would type. At least 3 terms.

**3. What do they need most urgently?**
The answer, not the explanation. Someone in crisis wants the fix first, the theory second. What is the one thing they came here to find out?

**4. Does the current design or naming match their search terms?**
Compare your working title, heading, or repo name against the search terms from question 2. If none of the search terms appear in your title, your work will not be found. Fix the title before proceeding.

**5. Can they find what they need in 30 seconds?**
Read your draft as someone arriving for the first time. Time yourself. If the answer is not visible within 30 seconds of landing, identify what is in the way and remove it.

**6. What would make them leave?**
List at least 2 things that would cause your target audience to close the tab immediately. Common causes: requires setup before answering the question, assumes knowledge they don't have, buries the answer below a wall of context, uses internal terminology they don't recognize.

## Output

Report your answers to all 6 questions. Do not proceed with the design until you can answer question 1 specifically. If you cannot name the audience, name what is blocking you and surface it to the operator.
