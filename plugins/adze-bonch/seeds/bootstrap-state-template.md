# Bootstrap State (template)

*Authoritative as of 2026-05-10. Template for the state-oracle doc per D10. Tag this doc `kind:bootstrap-state` and `provenance:canonical` when materialized.*

The bootstrap-state doc is the single source of truth for what adze-bonch has done in this adze instance. Setup reads it first and branches on its contents (fresh / partial / current / upgrade).

## YAML frontmatter (the load-bearing part)

```yaml
---
plugin_version: 0.1.0
install_at: 2026-05-10T00:00:00Z
last_sync_at: 2026-05-10T00:00:00Z

# Project IDs: established at bootstrap, never change
adze_workflow_plugin_project_id: <ulid>
user_profiles_project_id: <ulid>

# Canonical seed docs: per-file with hash for drift detection
canonical_seeds:
  - file: workflow.md
    document_id: <ulid>
    seed_hash: <sha256-hex>
  - file: named-protocols.md
    document_id: <ulid>
    seed_hash: <sha256-hex>
  - file: discipline.md
    document_id: <ulid>
    seed_hash: <sha256-hex>
  - file: bootstrap-state-template.md
    document_id: <ulid>
    seed_hash: <sha256-hex>
  - file: voice-default.md
    document_id: <ulid>
    seed_hash: <sha256-hex>
  - file: progress-format.md
    document_id: <ulid>
    seed_hash: <sha256-hex>
  - file: branch-naming.md
    document_id: <ulid>
    seed_hash: <sha256-hex>

# User identity: set after Step 3 of setup
user_profile_id: <ulid or null>

# Discoverability shims: append-only list of paths where a CLAUDE.md trampoline was installed
discoverability_installed_at: []

# SessionStart hook: set after Step 6 of setup (null if skipped)
session_hook_scope: null          # "project" | "global" | null
session_hook_installed_at: null   # absolute path to settings.json, or null
---
```

## Body

Below the frontmatter, prose context that explains what this doc is to a human reader who finds it cold:

```markdown
# Bootstrap State

This doc is read by `/adze-bonch:setup` and `/adze-bonch:main` to know what's been done in this adze instance. Editing it by hand is generally a mistake; re-run setup, which is idempotent.

## What setup uses this for

- **Fresh / current / upgrade detection.** Setup compares `plugin_version` against the running plugin's version.
- **Seed drift detection.** Setup recomputes each seed file's SHA256 and compares to `canonical_seeds[].seed_hash`. Mismatches trigger a supersede + new doc per Rule 2.
- **Resume on partial install.** Empty fields tell setup which step to start from.
- **Discipline doc resolution.** `/adze-bonch:main` Step 0 reads `canonical_seeds` to find the discipline doc id directly, no search needed.
- **SessionStart hook detection.** `session_hook_scope` and `session_hook_installed_at` tell setup whether the hook is already installed, preventing duplicate installs on re-run.

## When this doc gets updated

- After `/adze-bonch:setup` completes any step that creates or modifies infrastructure.
- After a manual seed re-run (future feature).
- Never by user-authored edits to commands or workflow.
```

## Schema rules (D10)

- **Versioned, idempotent.** `plugin_version` is the only field that's allowed to drive structural change.
- **Append-only for arrays.** Don't shrink `canonical_seeds` or `discoverability_installed_at` without going through a supersede.
- **One per adze instance.** Search-by-tag must return exactly one. If two are found, halt and ask the user to merge.
- **The doc itself is `concurrency:strict`**: re-read before writing if last read was >60s ago.

## Schema evolution

When a future plugin version adds a new field, set a sane default for installs that lack it. Don't break old installs. The `last_sync_at` timestamp helps a future migrate command know when to re-stamp.
