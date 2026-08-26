# Adze Progress Format (v1.0.0)

*Authoritative as of 2026-06-30. Defines the `kind:task-log` document shape used by the adze-bonch tackle workflow. Built on the [adze](https://github.com/4lt7ab/adze) substrate.*

## TL;DR

- One `kind:task-log` doc per task, bound to the task via `task_id` in a `---`-fenced frontmatter block.
- Tagged `concurrency:strict`: re-read before every append if the last read was more than 60 seconds ago.
- Always append, never overwrite. Each entry is a dated, one-line status append.
- One exception: the `**Run tally**` line under each session header is refreshed in place, not appended.

---

## Purpose

The task-log is the single source of truth for the in-flight state of a tackle session. The orchestrator appends to it synchronously before dispatching any sub-agent and after each step completes. If a session crashes or is resumed days later, the task-log is the recovery point.

---

## Document shape

Every task-log doc starts with a `---`-fenced frontmatter block in the document body, carrying the task binding and the concurrency rule:

```
---
task_id: {adze task id}
concurrency: strict
---
```

The doc title (`{task title} - Progress Log`) and the `kind:task-log` tag live on the adze document itself, set at creation; the body frontmatter only carries `task_id` and `concurrency`.

Below the frontmatter, the body is an ordered sequence of append entries, oldest first. The doc is created at Step 0 the first time the task is tackled; all subsequent sessions append to the same doc.

---

## Entry types

The orchestrator appends short, single-line, dated entries as it drives the pipeline. Two shapes recur, plus one line that is updated rather than appended.

### Run tally (updated in place)

One `**Run tally**` line sits directly under each session's `Session started.` entry. It is the single exception to the append-only rule: refresh it in place after each fix cycle or spawn so it always shows current totals.

```
**Run tally**: fix-cycles used {N} of ~8 soft cross-loop budget (across 4a/4b/4d), agents spawned {N}.
```

The soft cross-loop budget is defined in [workflow.md](workflow.md) Step 4: past roughly 8 total fix cycles, stop and reassess scope with the user even if no single failure hit the max-3 cap. Live token and turn metering is left to the harness and is not estimated here.

### Pre-dispatch anchor

Written synchronously BEFORE a sub-agent is spawned, as a crash-recovery anchor:

```
Spawning {agent name}{optional note, e.g. "(TDD: failing tests first)"}.
```

### Step-result entry

Written synchronously when a step completes, recording the outcome in one line:

```
{Step result}. {key}: {value}. {key}: {value}
```

The actual entries the orchestrator writes, in pipeline order, look like:

```
Session started. Task: {task title}.
**Run tally**: fix-cycles used {N} of ~8 soft cross-loop budget (across 4a/4b/4d), agents spawned {N}.
Spawning scrum-master for workflow routing.
Workflow: {type}. Documentation: {yes/no}. TDD: {yes/no}. Rationale: {1 sentence}.
Spawning researcher.
Research complete. Summary: {1-2 sentences}.
Plan approved. {N} steps. Approach: {1 sentence}. Done when: {1-line restatement, or the bulleted block for a standard workflow}.
Branch: {branch-name}.
Spawning test-writer (TDD: failing tests first).
TDD tests written. Files: {list}. Baseline: failing as expected.
Spawning implementer.
Implementation complete. Files: {list}. Verification: {pass/fail}.
Step 3.5 tests confirmed green. Verification: {pass/fail}.
Spawning quality gate reviewers in parallel.
Quality gate complete. Code Review: {N}. Acceptance QA: {pass/fail or skipped}. Edge Case QA: {N or skipped}. Code Smells: {N}. Test Review: {N or skipped}. Self-Containment: {N}. Comment Claims: {N}. Total: {N} findings.
Spawning repro-verifier.
Repro-verify complete. {N} confirmed, {N} proven-safe, {N} inconclusive. Gates: {result}.
Fix cycle complete. {N} applied, {N} deferred. Verification: {pass/fail}.
Committed: {hash} - {description}.
Handoff complete.
```

The `Done when:` value on the plan entry is the task-level Done-condition, copied verbatim from the `kind:plan` doc. It is what a post-`/clear` resume re-anchors on at Step 0, so it is echoed here rather than left only in the plan doc.

The quality gate entry carries a per-reviewer count for all seven reviewers, not just a total. `skipped` is a legitimate value for the reviewers a lightweight or docs-only workflow does not spawn; it is not a legitimate value for the repro-verify entry, which runs on every workflow.

Each new session begins with its own `Session started.` entry appended to the same doc, so the full history stays in one place.

---

## Rules

1. **Always append, never overwrite** previous entries. History must be recoverable. The one exception is the `**Run tally**` line under the session header, which is refreshed in place.
2. **Synchronous writes**: append before dispatching any agent. Save first, then spawn.
3. **Re-read before writing** if the last read was more than 60 seconds ago (concurrency:strict discipline from D4).
4. **One log per task**: when the task is resumed in a new session, append a new `Session started.` entry to the same doc; never create a second doc.
5. **Keep entries concise**: this is a log, not documentation. One-liners per field are the target.

---

## Full template

A new task-log doc starts with this skeleton. The orchestrator fills in the frontmatter at creation (Step 0) and appends the first entry immediately:

```markdown
---
task_id: {adze task id}
concurrency: strict
---

Session started. Task: {task title}.
**Run tally**: fix-cycles used 0 of ~8 soft cross-loop budget (across 4a/4b/4d), agents spawned 0.
```

---

## Relationship to kind:session-log

`kind:task-log` mirrors the existing `kind:session-log` shape but is scoped to a single adze task rather than an open-ended work session. A task-log lives for the lifetime of the task and is closed (not deleted) when the task reaches its final state.

---

## Open Questions

- [ ] Should the task-log doc use adze's native tagging for `kind:task-log`, or embed it in the body header?
- [ ] How does the orchestrator reliably query "get the task-log for task {id}" when multiple docs might match?
- [ ] Should verification failures get their own `kind:verification-failure` entries in this doc, or separate docs per failure event?

## Decisions Locked

- `kind:task-log` is the standard progress-log shape for adze-bonch in-flight task state (v1.0.0)
- `concurrency:strict` applies to all task-log docs: obey the 60-second re-read rule from D4
- Synchronous pre-dispatch writes are mandatory, following Rule 1 of the discipline doc
- One task-log doc per task: new sessions append a new `Session started.` entry to the existing doc, never create a second doc
- The `**Run tally**` line is the single append-only exception: one per session header, refreshed in place
- The Step 2 entry carries the task-level `Done when:` condition verbatim, so a post-`/clear` resume can re-anchor on it
