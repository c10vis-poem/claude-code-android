---
name: scope-framing
description: Before starting any research task, define what decision the research serves, what "done" looks like, and what is out of scope. Prevents research that answers the technically correct question but not the operationally relevant one.
user-invocable: true
disable-model-invocation: false
argument-hint: "<research topic>"
allowed-tools: Read, Bash, Glob, Grep
---

# Scope Framing

Answer every question before starting research. Write the answers into a brief scope document: one paragraph or a short list per question. Then proceed. If you cannot answer question 1, ask the user before starting.

## Required Questions

**1. What decision will this research serve?**
One sentence. Name the decision that will change based on what you find. If no decision is downstream of this research, the research has no purpose. Example: "Whether to use package X or build a custom implementation."

**2. Who will act on the findings?**
Name the actor: a user, an agent, or another system. Different actors need different formats and levels of detail. An agent needs a recommendation. A decision-maker needs tradeoffs. Someone following instructions needs steps.

**3. What does "done" look like?**
Name the specific deliverable that closes this research. Not "I understand the topic" but "a one-page comparison of options A, B, and C with a recommendation." Research without a defined end state expands forever.

**4. What is explicitly out of scope?**
Name at least 2 things you will not research. Naming exclusions forces a scope decision and prevents drift. If you cannot name exclusions, your scope is not defined yet.

**5. What would make this research useless?**
Identify failure modes before you start. Common causes: wrong scope (you answered a related but different question), stale data (the information is outdated for the version in use), missing context (you don't have access to a key constraint that changes the answer).

## Output

Write the scope document before doing any research. Save it or include it at the top of your research output. If scope cannot be defined (if question 1 has no answer), stop and ask the user to clarify the decision before you proceed.
