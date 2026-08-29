---
name: status
description: "Read-only adze project snapshot. One projects_brief call (or fallback). Never writes. Use /adze-bonch:status for a cheap 'where am I' check."
---

# adze-bonch -- Status

Read-only snapshot of the active adze project. Cheap. Never writes.

## Step 0: Resolve Project

Same lookup chain as `/adze-bonch:main` Step 2. There is no `repo:` tag; we FTS over the cwd basename instead. status.md is read-only, so any "ask the user" answer is cached for THIS invocation only, not for the session.

1. Session-cached project id (if main has already resolved one this session).
2. Explicit user arg (project id, slug, or title fragment) via `mcp__adze__projects_list({ q: <arg> })`.
3. FTS over the cwd basename via `mcp__adze__projects_list({ q: <basename> })`. Single hit only.
4. Ask the user to pick from a short list of active projects.

If no project resolves, print "No project resolved. Pass a project id or invoke /adze-bonch:main." Stop.

## Step 1: Fetch Brief

Prefer the brief endpoint if available:

```
mcp__adze__projects_brief({ id: <project_id> })
```

If `projects_brief` is not available, fall back to:

```
mcp__adze__projects_get({ id })
mcp__adze__tasks_list({ project_id: id })
mcp__adze__documents_list({ project_id: id, limit: 10, sort: "created_at:desc" })
```

## Step 1.5: Load the Project Pulse

Per D18, the Project Pulse is the primary view of this snapshot. Load it (read-only) via the standard lookup:

1. `mcp__adze__tags_list({ q: "kind:pulse" })` -> tag id.
2. `mcp__adze__documents_list({ tag_id })` for candidates.
3. `mcp__adze__documents_for_project({ project_id })` to cross-check attachment; the pulse is the doc present in BOTH sets.
4. `mcp__adze__documents_get({ id })` for its body.

**One-per-project rule:** if more than one `kind:pulse` doc attaches to this project, HALT and ask which is authoritative.

If no pulse exists, note it in the output and suggest `/adze-bonch:save` to create one.

**Load-time budget guard (D18 anti-bloat):** if the loaded pulse exceeds 25 lines, or clearly carries a backlog, multiple threads, or accumulated history, add a one-line warning to the output: "Pulse is over budget; run /adze-bonch:save to re-trim it and file the overflow as tasks." Read-only; status never rewrites the pulse.

## Step 2: Render Snapshot

Lead with the Pulse, then the rest of the snapshot. Print this layout:

```
Pulse
  Where we left off: {pulse "Where we left off" paragraph}
  Next move: {pulse "Next move"}
  Open for user: {pulse "Open for user", only if present}
  (if no pulse: "No pulse yet. Run /adze-bonch:save to create one.")

{project.title}
  status: {project.status}
  last touched: {humanized timestamp from updated_at}

Tasks
  {N} todo   {N} doing   {N} done   {N} blocked
  by kind:   feature {N}, bug {N}, chore {N}, ... (only show kinds present)

Blockers ({N})
  - [task.title]  ({kind:<x>}, group_key:{group_key})
  ... up to 5; if more, print "+ {M} more"

Open Questions ({N})
  Tasks with group_key:open-questions
  - [task.title]
  ... up to 5; if more, print "+ {M} more"

Recent Decisions (last 3 docs)
  - {created_at date}  {doc.title}

What's next
  {first task with status:todo, or 'No todo tasks. Refine or brainstorm.'}
```

## Hard Rules

- **NEVER WRITE.** No `documents_create`, no `tasks_update`, no `projects_update`. Status is read-only.
- **NEVER load attached docs in full.** Titles + dates only.
- If you find yourself wanting to surface a decision the user just made: do NOT capture it here. Tell the user to run `/adze-bonch:save`.

## Style

- Concise table-style output. No prose summaries.
- Skip empty sections (don't print "Blockers (0)").
