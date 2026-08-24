---
name: subagent-edit-verification
description: |
  Verify what an editing sub-agent actually did rather than trusting its report.
  Use when: (1) about to commit a diff produced by a sub-agent, (2) you told an
  agent to abort or stopped it and need to know whether it wrote anyway, (3) a
  file changed in a way nobody asked for, (4) a review agent is told to diff
  against git history for a file that was never committed, (5) an agent goes
  idle without returning a report. Covers the abort race, unrequested deletions,
  self-report drift, and the hunk-count check that catches all three.
author: Claude Code
version: 1.0.0
date: 2026-08-23
---

# Sub-agent Edit Verification

## Problem

Editing sub-agents report on their own work. Those reports are usually accurate and
occasionally not, and the failures are silent: an extra deletion in an unrelated
section, a write that lands after you told the agent to stop, a review whose premise
was never valid. If you commit on the strength of the report, the defect ships.

## Trigger conditions

- You are about to commit a diff an agent produced
- You told an agent to abort, or called TaskStop
- You asked a review agent to compare against `HEAD`
- An agent reports "nothing else changed"
- An agent goes idle without returning content

## Solution

1. **Count the hunks and the deletions yourself.**
   ```sh
   git diff --stat
   git diff | grep -c '^@@'        # hunks: must equal the number of changes requested
   git diff | grep -c '^-[^-]'     # deletions: must be 0 for a pure insertion
   ```
   A mismatch is the whole signal. It caught an agent that quietly removed two
   unrelated lines while making a requested edit elsewhere.

2. **Treat aborts as racy.** Stopping is not synchronous. A write can land between
   your restore and the stop taking effect. Order: send the abort, confirm the agent
   is stopped, THEN restore and verify. Verifying before the stop lands proves nothing.

3. **Commit before dispatching, so a baseline exists.** An untracked file has no
   history: `git diff` is empty and `git show HEAD:file` fails. A review agent asked
   to diff such a file has nothing to compare and may report on a premise that never
   held.

4. **Make the agent report numbers, then check them.** Require `git diff --stat`, the
   hunk count, and the resulting structure (heading order, first lines of the file).
   Discrepancies between the claim and the diff become visible immediately.

5. **Say what you actually verified.** If a check could not run, report that, rather
   than describing the check as done.

## Verification

Before any commit of agent-produced work: the stat matches expectation, hunk count
equals the number of requested changes, deletions are zero on a pure insertion, and
`git status` shows only the files you intended.

## Notes

- **Serialize edits to one file.** Two agents editing the same file concurrently is a
  lost update, and the second one's diff will look clean.
- **An idle notification is not a report.** If an agent goes idle without returning
  content, do the verification yourself instead of assuming it finished.
- **Give exact replacement text** plus a rule that anything outside it is a failure to
  be reported loudly. Vague instructions produce confident agents and quiet drift.
