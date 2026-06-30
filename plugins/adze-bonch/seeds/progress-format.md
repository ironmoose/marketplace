# Adze Progress Format (v1.0.0)

*Authoritative as of 2026-06-30. Defines the `kind:task-log` document shape used by the adze-bonch tackle workflow. Built on the [adze](https://github.com/4lt7ab/adze) substrate.*

## TL;DR

- One `kind:task-log` doc per task, bound to the task via `task_id` in a `---`-fenced frontmatter block.
- Tagged `concurrency:strict`: re-read before every append if the last read was more than 60 seconds ago.
- Always append, never overwrite. Each entry is a dated, one-line status append.

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

The orchestrator appends short, single-line, dated entries as it drives the pipeline. Two shapes recur.

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
Spawning scrum-master for workflow routing.
Workflow: {type}. Documentation: {yes/no}. TDD: {yes/no}. Rationale: {1 sentence}.
Spawning researcher.
Research complete. Summary: {1-2 sentences}.
Plan approved. {N} steps. Approach: {1 sentence}.
Branch: {branch-name}.
Spawning implementer.
Implementation complete. Files: {list}. Verification: {pass/fail}.
Spawning quality gate reviewers in parallel.
Quality gate complete. {N} total findings.
Fix cycle complete. {N} applied, {N} deferred. Verification: {pass/fail}.
Committed: {hash} - {description}.
Handoff complete.
```

Each new session begins with its own `Session started.` entry appended to the same doc, so the full history stays in one place.

---

## Rules

1. **Always append, never overwrite** previous entries. History must be recoverable.
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
