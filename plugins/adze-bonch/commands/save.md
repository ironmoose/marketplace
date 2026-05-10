---
name: save
description: "Synchronous decision capture. Audits the last N conversation turns, surfaces unpersisted decisions, asks which to capture, dispatches the writes immediately. The 'save our work' hammer per discipline Rule 1."
---

# adze-bonch — Save

The "save our work" hammer. Per discipline Rule 1 (synchronous decision persistence), conversation context evaporates and adze persists. This command audits recent turns, surfaces decisions that should be captured, asks the user which ones to write, and dispatches the writes IMMEDIATELY.

## Step 0: Load Discipline + Project

Same as `/adze-bonch:main` Steps 0-2. Resolve the active project.

If no project resolves, print "Save needs a project. Pass a project id, run from a tagged repo, or invoke /adze-bonch:main first." Stop.

## Step 1: Audit Conversation Context

Walk back through the last 10-20 turns of conversation. Categorize each candidate against Rule 1's trigger list:

**Triggers (write happens):**
- Direction pivot ("we're going X instead of Y") → project context update + supersede conflicting docs
- New playbook / pipeline / workflow defined → new dated doc
- Open question resolved → update relevant doc, remove the question
- Reference / artifact captured (image, file, link the user shared) → save to `~/workspaces/notes/<project>-*` + adze doc pointing to it
- Tooling chosen / rejected → update authoritative playbook + Decisions Locked
- Approach abandoned → supersede the prescribing doc

**Non-triggers (skip):**
- Exploratory chatter that didn't land
- Read-only research
- Implementation details inside an already-decided approach
- Reversible UI tweaks

For each trigger, draft:
- One-line summary
- Type (project_context_update / new_doc / supersede / task_create / task_update / artifact_capture)
- Target (project / doc id / file path)
- Proposed write payload (title, body, tags, supersedes)

## Step 2: Present and Ask

Print:

```
Decisions surfaced from recent turns:

  1. [type] {summary}
     -> {target}

  2. [type] {summary}
     -> {target}

  ...

Capture which? (all / numbers like '1,3' / none)
```

Wait for input.

If `none`: print "Skipped. Nothing written." Stop.

## Step 3: Dispatch Writes Synchronously

For each accepted item, in order:

| Type | Action |
|------|--------|
| `project_context_update` | `mcp__adze__projects_update({ id, context: <merged> })` |
| `new_doc` | `mcp__adze__documents_create(...)` then `mcp__adze__documents_attach({ project_id, document_id })` |
| `supersede` | (1) Read existing doc. (2) Prepend SUPERSEDED notice block per Rule 2. (3) Rename title to `[SUPERSEDED <YYYY-MM-DD>] <Original>`. (4) `mcp__adze__documents_update`. (5) Create the new authoritative doc per Rule 3. |
| `task_create` | `mcp__adze__tasks_create(...)` |
| `task_update` | `mcp__adze__tasks_update(...)` |
| `artifact_capture` | Write artifact to `~/workspaces/notes/<project-slug>-<artifact>-<YYYY-MM-DD>.{ext}`, then create an adze doc that links to it. |

**Concurrency rule (D4):**
- For docs tagged `concurrency:strict`: re-read with `documents_get` before writing IF last read was >60s ago. Skip re-read otherwise.
- For tasks (default `concurrency:lax`): skip the re-read.

**After each write succeeds, print:** `wrote: {type} -> {id-or-path}`

**If a write fails:** print the error, ask the user whether to retry, skip, or stop.

## Step 4: Append to Session Progress Log

After all writes, find or create the project's "Session Progress Log" doc (search by title under the project, tag `kind:session-log`). Append a dated entry summarizing what was captured this turn.

This append is also synchronous, not background.

## Hard Rules

- **Synchronous, always.** Never queue writes. Never batch into one giant doc dump at session end. The whole point of this command is to defeat that pattern.
- **Supersede, never delete.** If you rejected an approach, the doc that prescribed it gets superseded per Rule 2. Never `documents_delete`.
- **Project context updates aren't optional** (Rule 5). If a pivot landed, `projects_update` runs.
- **Memory vs adze split** (Rule 4): user-level facts go to memory (don't write under `~/.claude/`; instead, surface as a Tab/notes task per the user's no-dotclaude policy). Project facts go to adze.
- **No em-dashes** in any captured doc body or commit message.

## Style

- One question per turn when soliciting accept/reject.
- Show the diff or the new content before the write, briefly. The user should know what they're saying yes to.
