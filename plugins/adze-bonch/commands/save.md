---
name: save
description: "Synchronous decision capture. Audits the last N conversation turns, surfaces unpersisted decisions, asks which to capture, dispatches the writes immediately. The 'save our work' hammer per discipline Rule 1."
---

# adze-bonch -- Save

The "save our work" hammer. Per discipline Rule 1 (synchronous decision persistence), conversation context evaporates and adze persists. This command audits recent turns, surfaces decisions that should be captured, asks the user which ones to write, and dispatches the writes IMMEDIATELY.

## Step 0: Load Discipline + Project

Same as `/adze-bonch:main` Steps 0-2. Resolve the active project. Resolving project state now includes the Project Pulse (D18): the save flow updates it in Step 3.5, so keep the active project id handy.

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

## Step 3.5: Update the Project Pulse

Per D18, every save refreshes the Project Pulse: a per-project resume trailhead, updated IN PLACE (never superseded; the pulse is transient). The pulse has a hard size budget (<=25 lines, about 1500 characters, one active thread, one next action). Anything that does not fit is filed as a task, not crammed into the pulse; that is why the `pulse-writer` returns an overflow list.

1. **Compile recent context.** Gather what just happened this session: the decisions captured in Step 3, active task IDs, relevant doc IDs, commit hashes, and file paths.
2. **Load the existing pulse** via the standard lookup:
   - `mcp__adze__tags_list({ q: "kind:pulse" })` -> tag id.
   - `mcp__adze__documents_list({ tag_id })` for candidates.
   - `mcp__adze__documents_for_project({ project_id })` to cross-check attachment; the pulse is the doc present in BOTH sets.
   - `mcp__adze__documents_get({ id })` for its body.
   - **One-per-project rule:** if more than one `kind:pulse` doc attaches to this project, HALT and ask which is authoritative.
3. **Dispatch the `pulse-writer` sub-agent** (model haiku, read-only). Pass it: the project title, the compiled context, the existing pulse body (if any), and the effective voice. It DRAFTS the 3 canonical sections (Where we left off / Next move / Open for user) and RETURNS them inside a machine-parseable envelope (`===PULSE===` / `===OVERFLOW===` / `===END===`); it does not write to adze itself.
4. **Parse the envelope.** Split the returned message on the `===PULSE===`, `===OVERFLOW===`, and `===END===` markers:
   - The text between `===PULSE===` and `===OVERFLOW===` is the **pulse body**.
   - The text between `===OVERFLOW===` and `===END===` is the **overflow list**: zero or more items the writer trimmed to keep the pulse within budget, or the literal `(none)`.
5. **Show the pulse body** and ask the user to confirm.
6. **On confirm, write the pulse:**
   - If a pulse exists: `mcp__adze__documents_update` it IN PLACE. Concurrency is strict: re-read with `documents_get` first if the last read was >60s ago.
   - If none exists: `mcp__adze__documents_create` with tags `kind:pulse` and `provenance:user`, then `mcp__adze__documents_attach({ project_id, document_id })`.
7. **Print** `wrote: pulse -> {id}`.
8. **File overflow as tasks.** If the overflow list is `(none)`, skip this step. Otherwise print the trimmed items as a numbered list and ask:

   ```
   These didn't fit the pulse budget; file as tasks? (all / numbers / none)
   ```

   Wait for input. For each accepted item, call `mcp__adze__tasks_create({ project_id, title, context: body })` and print `wrote: task -> {id}`. This closes the loop: excess becomes tasks, not pulse bloat.

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
