# Adze Progress Format (v1.0.0)

*Authoritative as of 2026-06-30. Defines the `kind:task-log` document shape used by the adze-bonch tackle workflow. Built on the [adze](https://github.com/4lt7ab/adze) substrate.*

## TL;DR

- One `kind:task-log` doc per task, bound to the task via `task_id` in its header.
- Tagged `concurrency:strict`: re-read before every append if the last read was more than 60 seconds ago.
- Always append, never overwrite. Sessions get a `## Session:` header; steps get `### Step N:` entries.

---

## Purpose

The task-log is the single source of truth for the in-flight state of a tackle session. The orchestrator appends to it synchronously before dispatching any sub-agent and after each step completes. If a session crashes or is resumed days later, the task-log is the recovery point.

---

## Document shape

Every task-log doc starts with this header block in the document body:

```
title: {task title} - Progress Log
kind: task-log
task_id: {adze task id}
concurrency: strict
```

The body below the header is an ordered sequence of append entries, oldest first.

The doc is created at Step 0 the first time the task is tackled. All subsequent sessions append to the same doc.

---

## Entry types

### Session header

Written synchronously at the start of every session, before any other work:

```markdown
## Session: YYYY-MM-DD HH:MM

- Resumed from: {previous session date, or "new task"}
- Branch: `{branch}` ({N} commits ahead of default)
- Workflow: {standard | lightweight | docs-only | custom}, {rationale}
```

### Step entry

Written synchronously when a step completes:

```markdown
### Step {N}: {Step name}
- Status: {complete | skipped | blocked}
- {key field}: {value}
- {key field}: {value}
```

What goes in key fields depends on the step. The workflow doc ([workflow.md](workflow.md)) specifies the expected fields for each step. At minimum: status plus one line of substance.

### Pre-dispatch entry

Written synchronously BEFORE an agent is dispatched (not after):

```markdown
### Dispatching: {agent name}
- Plan steps: {which steps}
- Files in scope: {list}
```

### What-changed entry

Use at any point to record a notable mid-step event: a decision, a blocker, or a scope change:

```markdown
### Change: YYYY-MM-DD HH:MM
- What changed: {description}
- Next: {what the orchestrator will do}
- Decisions: {any decisions locked from this change, or "none"}
```

---

## Rules

1. **Always append, never overwrite** previous entries. History must be recoverable.
2. **Synchronous writes**: append before dispatching any agent. Save first, then spawn.
3. **Re-read before writing** if the last read was more than 60 seconds ago (concurrency:strict discipline from D4).
4. **One log per task**: when the task is resumed in a new session, add a new `## Session:` header to the same doc.
5. **Keep entries concise**: this is a log, not documentation. One-liners per field are the target.

---

## Full template

A new task-log doc starts with this skeleton. Fill in the header and first session block at Step 0:

```markdown
title: {task title} - Progress Log
kind: task-log
task_id: {adze task id}
concurrency: strict

## Session: YYYY-MM-DD HH:MM

- Resumed from: new task
- Branch: (none yet)
- Workflow: (pending Step 0.5)

### Step 0: Load Context
- Status: complete
- Task: {task title}
- Git state: {branch or "not branched yet"}, {N} commits ahead of default
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
- One task-log doc per task: new sessions append a new Session block to the existing doc, never create a second doc
