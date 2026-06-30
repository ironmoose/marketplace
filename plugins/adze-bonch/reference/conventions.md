# Standards Model

This document is the canonical read-target that every adze-bonch builder and reviewer agent cites. It defines where to find conventions, which conventions take precedence, and why the model is "read, do not bake."

---

## Core rule

Agents enforce the conventions of the target project, not a fixed ruleset embedded in their prompts. This keeps the plugin project-agnostic and ensures it stays in sync with whatever standards the target team maintains.

---

## How to locate conventions

When starting work on any adze task, agents load conventions in this order:

1. **Root CLAUDE.md** of the target repository (the repo being modified). Read it fully using your Read tool.
2. **Nearest nested CLAUDE.md** relative to the files being changed. "Nearest" means the closest ancestor directory to the changed files that contains a `CLAUDE.md`. If the root is already the closest, read it once (do not double-count).
3. **Adze-side overrides** (session override, project `workflow_overrides`, user profile, canonical default) are resolved by the orchestrator via a lookup chain before your prompt is built. You receive the effective values as injected context in your prompt. You do not call adze to fetch them.

If no `CLAUDE.md` exists in the target repo, fall back to general good-practice for the detected language and stack.

---

## Precedence order

First hit wins. Cache the result for the duration of the current turn.

| Priority | Source | When it applies |
|----------|--------|-----------------|
| 1 | Session override | User says explicitly "for this task, do X" |
| 2 | Project workflow_overrides | Active adze project `context` contains a `workflow_overrides` block |
| 3 | Target-repo CLAUDE.md | Root + nearest nested (steps 1 and 2 above) |
| 4 | General good-practice | No CLAUDE.md found, or topic is silent in the CLAUDE.md |

---

## What "enforce" means in practice

- Apply the rules found during the read above, not any baked-in list in the agent prompt.
- When a rule in the target repo's CLAUDE.md contradicts a general heuristic, the repo rule wins.
- When the CLAUDE.md is ambiguous or silent on a topic, use judgment consistent with the detected stack and patterns already present in the codebase.
- Do NOT invent rules that are not present in the CLAUDE.md or visible in the existing codebase patterns.
- If no CLAUDE.md exists and the stack is unambiguous (e.g. Python with pytest), apply the community-standard conventions for that stack.

---

## Adze

The adze task tracking system powering adze-bonch is maintained at [https://github.com/4lt7ab/adze](https://github.com/4lt7ab/adze).
