# Adze Branch Naming (v1.0.0)

*Authoritative as of 2026-06-30. Defines how the adze-bonch tackle workflow names git branches. Built on the [adze](https://github.com/4lt7ab/adze) substrate.*

## TL;DR

- Pattern: `<kebab-summary>`, derived from the adze task title.
- No ticket prefix by default. Adze tasks use adze IDs, not external ticket keys.
- Branch from the repo's default branch (usually `main` or `master`).
- Override the pattern via `workflow_overrides` in the project context (D6 lookup chain).

---

## Standard

- **Pattern**: `<kebab-summary>`
- **kebab-summary**: 2-4 words in kebab-case, derived from the adze task title. Drop stop words; keep the core verb and noun.
- **Branch from**: the repo's default branch. Confirm with the user if the repo uses a non-standard base branch.

---

## Examples

| Adze task title | Branch name |
|-----------------|------------|
| Fix login timeout error | `fix-login-timeout` |
| Add CSV export to reports | `add-csv-export` |
| Upgrade React dependencies | `upgrade-react-deps` |
| Refactor auth module | `refactor-auth-module` |
| Write docs for settings API | `docs-settings-api` |

---

## Overrides via lookup chain

The D6 lookup chain applies to branch naming:

1. **Session override**: user says "call it `feature/csv-export`" in the current message.
2. **Project `workflow_overrides`** in `project.context`: e.g., `branch_prefix: "feature/"` or `include_task_prefix: true` if the project tracks tasks with a short identifier.
3. **User profile doc** (tagged `user-profile:{username}`): user-level preference (e.g., always use `{username}/` prefix).
4. **This canonical default**: `<kebab-summary>`, no prefix.

First hit wins. Cache for the duration of the session.

---

## Rules

- Confirm the branch name with the user before creating it if the task title is ambiguous or very long.
- If the repo has a visible branch convention in `git branch` output, follow the repo's existing pattern rather than this standard.
- If the project's `workflow_overrides` sets `include_task_prefix: true`, prefix with `{task-prefix}-` where `task-prefix` comes from the project context (e.g., a short project code).
- Always branch from the default. Do not branch from a feature branch unless the task explicitly calls for stacked branches.
- When resuming a session on an existing branch: `git switch {branch}` (no `-c`). Confirm with the user before reusing a branch that has commits not yet on origin.

---

## Open Questions

- [ ] How to handle cross-repo tasks that need coordinated branches across multiple repos (same name everywhere, or repo-scoped names)?
- [ ] Should stacked-PR workflows get a naming convention here, or a separate doc?
- [ ] If a project has both an adze task id and a short external reference (e.g., a sprint card number), which takes priority in the prefix?

## Decisions Locked

- No ticket prefix by default: adze tasks have adze IDs, not external ticket keys, and IDs are not human-readable branch prefixes
- `<kebab-summary>` is derived from the adze task title only, not from any external tracking system
- Override path follows the standard D6 lookup chain from discipline.md
- Branching always starts from the repo default unless the task or user explicitly specifies otherwise
