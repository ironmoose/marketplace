# pr-review

Multi-agent PR review plugin for Claude Code. Dispatches 5-7 specialized review agents in parallel, deduplicates and ranks their findings, then walks you through each one individually so you control exactly what gets posted. Comments are drafted in a natural teammate voice with strict rules against AI tells.

## Review Pipeline

1. **Context gathering** - Fetches PR metadata, diffs, inline comments, and conversation comments in parallel.
2. **Parallel review agents** - 5-7 agents analyze the PR simultaneously, each with a different focus area.
3. **Consolidation** - Findings are deduplicated, merged, and sorted by severity.
4. **One-at-a-time walk-through** - Each finding is presented individually. You choose: comment, skip, or tweak.
5. **Draft review** - A top-level blurb plus approved inline comments, presented for final review.
6. **Post on approval** - Nothing is posted until you say "post" or "go."

## Agent Lineup

| Agent | Focus | Condition |
|-------|-------|-----------|
| Edge Case QA | Boundary conditions, null handling, race conditions, async edge cases, error paths | Always |
| Acceptance QA | PR claims vs. actual code, data flow tracing, stale state bugs, test coverage gaps | Always (highest priority) |
| Researcher | Git blame, prior PRs, history patterns, stale TODOs | Always |
| Code Reviewer | CLAUDE.md standards compliance (only explicitly stated rules) | Always |
| Code Smells | Fowler catalog: long methods, feature envy, data clumps, coupling, complex conditionals | Always (skips test files) |
| Test Reviewer | Hollow assertions, over-mocking, AI-generated test smells, mock leak | Only when test files are in the changeset |
| Dynamic Specialists | Migrations, CI/CD, Docker/infra, Claude skill files | Only when relevant artifacts are in the changeset |

## Voice Rules

Comments read like a teammate wrote them, not a bot.

- Lead with the observation, not a greeting
- Frame feedback as observations or questions, not commands
- Structure: what's wrong, why it matters, suggested fix
- Contractions are fine ("don't", "isn't", "won't")
- No em dashes, no "Hey!" openers, no "just wanted to flag", no "not blocking!"
- No AI attribution, no inline praise-only comments, no lecture-style explanations
- Git blame before commenting on pre-existing issues (frame differently based on authorship)

## Modes

**Dashboard mode** (no arguments): Lists all open PRs across repos in a numbered table. Pick a number to start a review.

**Review mode** (PR URL or dashboard number): Runs the full review pipeline on a specific PR.

## Install

```
/plugin marketplace add ironmoose/marketplace
/plugin install pr-review@ironmoose-marketplace
```

## Usage

```
/pr-review:review                    Show open PR dashboard
/pr-review:review {PR URL}           Review a specific PR
/pr-review:review #3                 Review PR #3 from dashboard
```

## Integrations

The review pipeline auto-detects available integrations. No configuration needed.

- **GitHub** (always available) -- PR metadata, diffs, comments, review posting via `gh` CLI
- **Jira** (optional) -- if Jira MCP tools are configured, pulls ticket context and acceptance criteria

The more context available, the stronger the Acceptance QA agent's verification. But the core review works with just GitHub.

## Credits

By Paul Parker. Part of the [ironmoose/marketplace](https://github.com/ironmoose/marketplace) plugin collection.
