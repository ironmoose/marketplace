# Project Pulse (v1.0.0)

*Authoritative as of 2026-07-01. Defines the `kind:pulse` document shape: the per-project session-resume trailhead used by the adze-bonch save and tackle workflows. Built on the [adze](https://github.com/4lt7ab/adze) substrate.*

## TL;DR

- One Pulse doc per project, tagged `kind:pulse` AND `provenance:user`, `concurrency:strict`.
- The FIRST thing an agent loads when entering a project. A resume trailhead, NOT a full status report.
- Three sections, about 10-25 lines: Where we left off, Next move, Open for user.
- Updated IN PLACE on every `/adze-bonch:save`; never superseded, never grown with history.

---

## Purpose

The Pulse answers one question for a returning agent: "where did we leave off, and what's the single next move?" It is the resume trailhead an agent reads before anything else when re-entering a project.

It deliberately holds only transient state. Stable, long-lived information lives elsewhere and must not be duplicated here:

- **`project.context`** -- the project's standing description and workflow overrides.
- **The target repo's `CLAUDE.md`** -- architecture, conventions, load-bearing pointers.
- **The design log** -- locked decisions and their rationale.

Keep the Pulse short. If a fact is stable, it belongs in one of the surfaces above, and the Pulse just points at it.

---

## Document shape

Every Pulse doc follows this three-section template. Aim for 10-25 lines total.

```
# Pulse - <project title>

**Saved:** <YYYY-MM-DD HH:MM>

## Where we left off

[One paragraph, 2-5 sentences, conversational. What was just happening, what state we reached, the natural pickup point. NAMES concrete task IDs / doc IDs / commit hashes / file paths so detail can be fetched. Written like a note to future-you, not a status report.]

## Next move

[1-3 lines. The single most natural next action. Concrete enough that the agent says "last time we said we'd do X".]

## Open for user

[Only if a question awaits the user's input. Otherwise omit the section, or write "(none)".]
```

The `# Pulse - <project title>` H1 and the `**Saved:**` stamp head the body. The `Open for user` section is present only when a question is genuinely pending; otherwise omit it or write "(none)".

---

## Size budget and anti-bloat

The Pulse is a lead, not a log. These rules keep it from growing into a status report that should be tasks. They are canonical (the D18 anti-bloat refinement).

1. **Size budget.** Whole pulse <= 25 lines and about 1500 characters. "Where we left off" is ONE paragraph, <= 5 sentences. "Next move" is <= 3 lines. "Open for user" is <= 2 lines (one question).
2. **Single thread only.** The pulse covers the ONE currently-active thread. Independent parallel threads are NOT listed; they live as tasks. The pulse names the active one.
3. **One next action.** "Next move" is exactly one action. Additional candidate actions are filed as tasks, never enumerated inline. The pulse may reference a task by ID but never grows a to-do list.
4. **No history.** "Where we left off" is OVERWRITTEN every save, never appended. Multi-session narrative goes to the Session Progress Log; decisions to the design log; research to docs.
5. **Overflow becomes tasks.** Whenever drafting would exceed the budget or violate single-thread / one-action, the excess is EXTRACTED into adze tasks. The pulse keeps only the lead. The `pulse-writer` sub-agent returns trimmed items in an OVERFLOW list; `/adze-bonch:save` files each accepted item as a `kind:task`.
6. **Load-time guard.** `/adze-bonch:main` and `/adze-bonch:status` warn if a loaded pulse is over budget (>25 lines, or carrying a backlog / multiple threads / history) and recommend `/adze-bonch:save` to re-trim and file overflow as tasks.

---

## Quality rules

1. **"Where we left off" names concrete anchors.** Real task IDs, doc IDs, commit hashes, and file paths, so a reader can fetch the detail. No "we did stuff" abstractions.
2. **"Next move" picks ONE action.** The single most natural next step, not a menu. Multi-option choices belong in tasks.
3. **Write a conversational paragraph, not bulleted fragments.** "Where we left off" is prose, a note to future-you.
4. **No em-dashes.** Use commas, semicolons, parentheses, or periods.
5. **Use specific verbs.** Implement, back-fill, decide, wire, migrate. Not vague ones like continue, work on, handle.
6. **Stay within the size budget.** Whole pulse <= 25 lines / about 1500 chars, one paragraph for "Where we left off", one action for "Next move", one question for "Open for user". See "Size budget and anti-bloat".
7. **Overflow becomes tasks, never pulse bloat.** A second thread, a second next-action, a backlog item, or extra open questions get extracted into adze tasks, not listed inline.

---

## Tag and concurrency

- **Tags**: `kind:pulse` AND `provenance:user`, set on the adze document at creation.
- **Concurrency**: `concurrency:strict`. Re-read the doc before writing if the last read was more than 60 seconds old (the D4 rule).

---

## One-per-project rule

A project has AT MOST ONE Pulse doc. If a lookup finds multiple `kind:pulse` documents attached to a single project, do NOT guess. HALT and ask the user which one is authoritative, then reconcile down to one.

---

## Lifecycle

- **Created**: the first time `/adze-bonch:save` runs on a project that has no Pulse (or via `/adze-bonch:tackle` when starting work on a project without one).
- **Updated in place**: synchronously on every `/adze-bonch:save`. The Pulse is transient state, so it is REPLACED, not superseded. The supersede pattern (prepend a SUPERSEDED notice, keep history) does NOT apply here.
- **Auto-trimmed**: no historical sections accumulate. Each save overwrites the three sections with the current state; old "Where we left off" text is discarded, not archived.

The writer is a dedicated read-only sub-agent, `pulse-writer` (model haiku), which DRAFTS the three sections and RETURNS them. The orchestrator shows the draft, confirms with the user, then writes to adze. The sub-agent never writes to adze itself.

---

## Open Questions

- [ ] Should a Pulse ever link its "Next move" to a concrete `kind:task` so the trailhead and the backlog stay in sync automatically?
- [ ] When resuming, should the agent diff the Pulse against the latest `kind:task-log` entry to detect a stale Pulse?
- [ ] Does `provenance:user` need a companion `provenance:agent` variant for auto-generated pulses, or is the single provenance sufficient?

## Decisions Locked

- One Pulse per project, tagged `kind:pulse` + `provenance:user`, `concurrency:strict` (v1.0.0)
- The Pulse is a resume trailhead, not a status report: transient state only, stable info stays in `project.context`, `CLAUDE.md`, and the design log
- Three fixed sections (Where we left off, Next move, Open for user), about 10-25 lines, no historical accumulation
- Updated in place on every `/adze-bonch:save`; never superseded, since the pulse is transient
- Drafted by the read-only `pulse-writer` sub-agent, confirmed with the user, then persisted by the orchestrator
- Size budget and anti-bloat (the D18 anti-bloat refinement): pulse <= 25 lines / ~1500 chars, single active thread, one next action, no history; overflow is extracted into tasks by the pulse-writer plus /adze-bonch:save, and main/status warn when a loaded pulse is over budget
