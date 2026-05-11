---
name: status
description: "Read-only adze project snapshot. One projects_brief call (or fallback). Never writes. Use /adze-bonch:status for a cheap 'where am I' check."
---

# adze-bonch — Status

Read-only snapshot of the active adze project. Cheap. Never writes.

## Step 0: Resolve Project

Same lookup chain as `/adze-bonch:main` Step 2. v0.1.0 has no `repo:` tag; we FTS over the cwd basename instead. status.md is read-only, so any "ask the user" answer is cached for THIS invocation only, not for the session.

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

## Step 2: Render Snapshot

Print this layout:

```
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
