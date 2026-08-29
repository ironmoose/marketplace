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
version: 1.1.0
date: 2026-08-27
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

### The idle agent: why it happens, and how to prevent it

An agent that goes idle without returning a report is not a mystery and not a
crash, and whether it can happen at all depends on how the spawn was made. A
sub-agent spawned WITH a `name` is an `in_process_teammate`, and a named teammate's
final assistant text has NO automatic return channel to the spawner: the mailbox is
the only channel, so a named agent that never calls `SendMessage` delivers nothing
at all, no matter how completely it did the work. An UNNAMED spawn behaves
differently, and its final assistant text comes back normally (controlled test,
2026-08-29).

State the consequence precisely. Naming a spawn removes the automatic return
channel; it does not by itself lose the report. What arrives after that depends on
the agent actively sending, and the same test showed both outcomes: named spawns
whose own agent definition mandated `SendMessage` still delivered, and named spawns
whose definition did not mandate it delivered nothing. Delivery correlates with
calling `SendMessage`: in one measured session, 21 agents that called it delivered
and 4 that did not call it delivered nothing.

A contributing cause worth naming: agent definition files often scope `SendMessage`
to asking questions, while their Output Format section says to "return" the report.
Those instructions actively point away from the only channel a named spawn has.

**The preventive fix.** Instruct the agent, at the TOP of its prompt, to deliver its
COMPLETE report as the body of a `SendMessage` to its spawner. Do not have it write
the report to a file: the harness rejects sub-agent report files, which is why
`agents/repro-verifier.md` forbids it outright for its own lane. A reusable preamble:

```
DELIVERY: your final assistant message does not reach your spawner and will be
discarded. Send your COMPLETE report as the body of
SendMessage({to: "<spawner>", message: "<the full report>"}). Do not write it to a
file. If it is too long for one message, send it in sequential parts rather than
truncating or dropping any of it.
```

Before any delivery instruction was added, five agents in a row went idle without
reporting, one of them twice after being asked directly to report. Every agent given
an explicit delivery instruction afterward delivered. That measured run used an
earlier form of the preamble, which had the agent write the report to a file and
send a one-line confirmation; having a delivery instruction at all is what moved the
number, and the body-of-the-message form above avoids the file rejection.

**An idle agent says nothing about whether it did the work.** In every observed case
the work was complete and correct; only the report was lost. So an idle notification
is a signal to go verify the files, never a signal to re-run the task. Re-running
risks duplicate or conflicting edits.

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
