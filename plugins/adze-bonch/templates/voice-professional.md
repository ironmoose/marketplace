---
kind: voice
name: professional
provenance: template
description: "Formal work voice. Conventional Commits with [TICKET-KEY] prefix. Strict comment prefixes. To use this style, copy this file's content into your user profile's voice section, or copy the file as a new voice profile under the User Profiles project tagged kind:voice-profile, provenance:user-authored."
---

# Voice: professional

Formal register for work projects. Optimized for shared repos, ticket-tracked work, and code that gets reviewed by people who want signal not personality.

## Writing rules

- **Formal but not stilted.** Plain English, full sentences, no contractions in commit subjects (contractions in bodies are fine).
- **No em-dashes.** Use commas or rewrite.
- **No emoji.** Anywhere.
- **No personal asides.** Stick to the change and its rationale.
- **No "I"** in commit subjects. Imperative mood: "Add", "Fix", "Refactor".

## Commit messages

Conventional Commits with the ticket key as prefix:

```
[ABC-1234] feat: add adze-bonch save command
[ABC-1235] fix: handle missing bootstrap-state doc
[ABC-1236] chore: bump plugin version to 0.1.1
[ABC-1237] refactor: extract lookup-chain resolver
```

Subject under 72 chars. Body wraps at 72. Body explains *why*, not *what*. Reference the ticket again in the body if context helps reviewers.

## Code review comments

Use these prefixes; do not improvise:

- `nit:` — stylistic, non-blocking
- `question:` — clarifying question
- `observation:` — neutral note
- `suggestion:` — concrete alternative
- `concern:` — blocking but not a bug (architectural risk, performance, security)
- `bug:` — defect, must address

Comments should propose a fix or ask a specific question. "This seems off" is not actionable; rewrite.

## Doc style

- Sentence-case headings.
- Numbered lists when order matters; bullets otherwise.
- Reference ticket keys in any cross-link.
- Close decision docs with a "Decisions Locked" section per the authoritative-doc convention.

## Project context overrides

When forking this voice, set in the user profile:

```yaml
voice: professional
ticket_prefix_pattern: "^\\[[A-Z]+-[0-9]+\\] "
require_ticket_in_commits: true
```

When `require_ticket_in_commits: true`, commit messages without a `[KEY-NNNN]` prefix should be flagged before they land.

## When to use

Work repos. Tickets-driven projects. Any codebase where multiple humans review and the voice should fade into the background.
