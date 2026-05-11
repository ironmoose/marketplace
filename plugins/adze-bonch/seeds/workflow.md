# Adze Workflow (v0.1.0 placeholder)

*Authoritative as of 2026-05-10. Stub — refined as patterns emerge from real usage.*

This is the canonical "how do I work in adze" doc. v0.1.0 ships it as a stub on purpose. Per D2, we build the plugin, use it on real work, then refine this doc from observed friction.

## TL;DR

- Synchronous decision persistence (Rule 1 of the discipline doc).
- Concept-aligned projects, not repo-aligned (D7).
- `kind:` tags carry task type (D8).
- Lookup chain: session override > project workflow_overrides > user profile > canonical (D6).
- Two adze projects exist for plugin infra: "adze-bonch reference" and "adze-bonch user profiles" (D9).

## Project shape

v0.1.0 treats every project as a flat work-stream. No `shape:` tag, no `repo:` tag, no project-level typed metadata. Adze projects can't carry tags in the current schema, so the plugin works with what FTS over project title gives us.

The earlier design proposed `shape:work-stream` / `shape:ticket` for project type and `repo:<name>` (multi-tag) for cross-repo provenance. Both were parked per D17 until adze supports project tagging or another encoding lands. Two research docs in adze hold the unshipped design:

- `01KRANRSBMCPZHQ31K2VQ78KTW` (upstream C-path pitch for project tags)
- `01KRANSF16K4VHFTMB5ZPNDN1G` (hybrid encoding via doc-tag oracle)

v0.2.0 may revive structured metadata once one of those lands.

## Task kinds

The `kind:` namespace replaces the earlier "classifier" idea (D8). A task can carry multiple kinds. Common values:

- `kind:research`
- `kind:bug`
- `kind:feature`
- `kind:chore`
- `kind:docs`
- `kind:test`
- `kind:spike`
- `kind:design`
- `kind:review-finding`
- `kind:verification-failure`
- `kind:qa-finding`
- `kind:governance` — flagged via the [GOVERNANCE] protocol

`group_key` stays reserved for phase or area (e.g. `group_key:auth`, `group_key:open-questions`, `group_key:bootstrap`). Don't double-purpose it for kind.

## Workflow phases (sketches; v0.1.0 doesn't ship commands for all of these yet)

| Phase | Sketch | v0.1.0 status |
|-------|--------|---------------|
| brainstorm | idea -> draft project + tasks | not shipped — manual via projects_create |
| refine | walk tasks, flesh out plan + acceptance | not shipped |
| tackle | dispatch implementer agent + review gate | not shipped |
| save | audit recent turns, capture decisions | shipped: `/adze-bonch:save` |
| status | read-only snapshot | shipped: `/adze-bonch:status` |
| verify | lint/typecheck/test loop | not shipped |

Future iterations of this doc will spell out tackle and verify in detail. For now: dispatch sub-agents manually, follow the named protocols (see `named-protocols.md`), and lean on `/adze-bonch:save` to keep adze in sync.

## Open Questions

- [ ] Concrete trigger list for the brainstorm flow's "draft project" cutover (when does an idea become a real project?)
- [ ] How tackle handles cross-repo work (worktree per repo vs. single nav)
- [ ] Whether refine should spawn research agents automatically for unknowns
- [ ] What "done" means at the project level (status field, or task-completion-derived)

## Decisions Locked

- Reference docs LIVE IN adze (D1)
- Two-project bootstrap: adze-bonch reference + adze-bonch user profiles (D9, renamed per D16)
- Concurrency: strict for reference, lax for tasks, with 60s read-cache (D4)
- Discipline rule lives in adze, no `~/.claude/rules/` install (D11)
- Discoverability via safe-path CLAUDE.md trampolines only (D12)
- Single canonical voice ships; others are templates (D13)
