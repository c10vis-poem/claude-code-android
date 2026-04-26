---
name: search-optimized-writing
description: Write documentation that is findable via search engines. Structure headings as questions people search, include exact error messages, use the terms users actually type. Use when writing README sections, troubleshooting entries, or guides.
user-invocable: true
disable-model-invocation: false
argument-hint: "<document or section you're writing>"
allowed-tools: Read, Bash, Glob, Grep
---

# Search-Optimized Writing Checklist

Apply every check to the document or section before publishing. Report any heading that should be rephrased, any error string that should be added, or any section where the answer is buried below the explanation.

## Checks

**1. What would someone Google to find this?**
List the exact error messages or symptom strings a user would paste into a search engine. Copy them character-for-character as they appear in the terminal or browser, capitalisation, punctuation, and all.

**2. Are those exact strings in the document?**
Search your draft for each string from check 1. If a string is missing, add it: in a code block if it is a terminal error, in plain text if it is a symptom description. A user who pastes the error into Google must be able to land on your page.

**3. Are headings phrased as searches, not topics?**
Compare your headings against how someone would phrase the problem. Prefer the user's language over internal terminology:
- Prefer: "Claude Code won't start on Android" over "Launch Procedure"
- Prefer: "npm fails silently" over "Package Manager Configuration"
- Prefer: "How do I fix TMPDIR?" over "Environment Variables"

Rephrase any heading that uses internal jargon a first-time user would not know.

**4. Are the most important keywords in the first 50 words?**
Read the first 50 words of the document or section. The problem being solved and the platform or context must appear there. Search engines weight early content heavily. If the topic is not stated in the first two sentences, move it.

**5. Does the document answer before it explains?**
Check the structure: answer first, explanation second. A user in crisis reads the fix, then decides whether to read the why. If your document explains background before giving the answer, invert the order.

## Output

Report as a checklist:
- Checks that pass: one line each.
- Checks that fail: what to fix and the specific location in the document.

Apply fixes to the document before reporting complete.
