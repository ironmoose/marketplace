# Standards Model

This document is the canonical read-target that every adze-bonch builder and reviewer agent cites. It defines where to find conventions, which conventions take precedence, and why the model is "read, do not bake."

---

## Core rule

Agents enforce the conventions of the target project, not a fixed ruleset embedded in their prompts. This keeps the plugin project-agnostic and ensures it stays in sync with whatever standards the target team maintains.

"Read, do not bake" governs **project** rules, and the plugin bakes none of them: no repo layout, no framework choice, no team policy, no house style. What the plugin does ship is a **language** baseline, the conventions overlay described below. The overlay gives the read-do-not-bake model a floor, so a repo with a thin or missing `CLAUDE.md` still gets sane language-level rules instead of whatever the agent happens to guess. It is a floor, never a ceiling: a repo that has spoken always wins.

---

## The conventions overlay (the language baseline)

`reference/typescript-conventions.md` and `reference/python-conventions.md` carry only rules that are true of the *language* itself: type safety, nullability, error handling, test structure. Anything true of a particular repo, stack, or framework does not belong in them; it belongs in that repo's own `CLAUDE.md`.

The orchestrator detects the changed code's language and names the matching overlay in the spawn prompt of the language-sensitive agents.

**Receive an overlay:** implementer, test-writer, code-reviewer, code-smells-reviewer, test-reviewer, edge-case-qa. All six ship as language-neutral skeletons, so the overlay is where their language rules come from.

**Receive none:** acceptance-qa, self-containment-reviewer, repro-verifier, researcher, scrum-master, pulse-writer. Each reasons about task criteria, private-context leaks, or runtime behavior rather than language conventions, so an overlay would add noise without changing its verdict.

How the language is detected, and at which step the orchestrator resolves it, is defined once in `seeds/workflow.md` (its language-detection and conventions-overlay-injection section). That seed is the single source of truth for the detection rule; it is deliberately not restated here.

---

## How to locate conventions

When starting work on any adze task, agents load conventions in this order:

1. **Root CLAUDE.md** of the target repository (the repo being modified). Read it fully using your Read tool.
2. **Nearest nested CLAUDE.md** relative to the files being changed. "Nearest" means the closest ancestor directory to the changed files that contains a `CLAUDE.md`. If the root is already the closest, read it once (do not double-count).
3. **The conventions overlay** named on the `Conventions overlay:` line of your spawn prompt, if you are one of the six agents that receives one. Read it and apply it, deferring to the target repo's `CLAUDE.md` wherever both speak to the same thing.
4. **Adze-side overrides** (session override, project `workflow_overrides`, user profile, canonical default) are resolved by the orchestrator via a lookup chain before your prompt is built. You receive the effective values as injected context in your prompt. You do not call adze to fetch them.

If no `CLAUDE.md` exists in the target repo, the overlay is your baseline, and general good-practice for the detected language and stack covers whatever the overlay leaves open.

---

## Precedence order

First hit wins. Cache the result for the duration of the current turn.

| Priority | Source | When it applies |
|----------|--------|-----------------|
| 1 | Session override | User says explicitly "for this task, do X" |
| 2 | Project workflow_overrides | Active adze project `context` contains a `workflow_overrides` block |
| 3 | Target-repo CLAUDE.md | Root + nearest nested (steps 1 and 2 above) |
| 4 | Conventions overlay | The language baseline named in your spawn prompt, on any topic the CLAUDE.md does not cover |
| 5 | General good-practice | No CLAUDE.md and no overlay, or the topic is silent in both |

---

## What "enforce" means in practice

- Apply the rules found during the read above, not any baked-in project ruleset in the agent prompt.
- When a rule in the target repo's CLAUDE.md contradicts a general heuristic, the repo rule wins.
- When a rule in the target repo's CLAUDE.md contradicts the overlay, the repo rule wins there too. Never impose an overlay rule over a committed standard. If the divergence looks like a real gap in the repo rather than a deliberate choice, flag it instead of silently overriding.
- When the CLAUDE.md is ambiguous or silent on a topic, apply the overlay if you have one; otherwise use judgment consistent with the detected stack and the patterns already present in the codebase.
- Do NOT invent project rules that are absent from the CLAUDE.md, from the overlay, and from the existing codebase patterns.
- If no CLAUDE.md exists and the stack is unambiguous (e.g. Python with pytest), apply the overlay plus the community-standard conventions for that stack.

---

## Adze

The adze task tracking system powering adze-bonch is maintained at [https://github.com/4lt7ab/adze](https://github.com/4lt7ab/adze).
