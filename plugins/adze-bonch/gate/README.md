# adze-bonch verification gate

The adze-bonch workflow says a code-review finding is not settled until an
executable repro has proven it. This directory holds the two files that
*enforce* that, so the enforcement mechanism ships with the plugin instead of
living only on whichever machine it was first written on.

- `gate-check.sh` — the `PreToolUse` hook that blocks edits.
- `adze-gate` — the CLI that opens, verifies, and closes a gate cycle.

Both are plain bash and need only `jq`, `sha256sum`, and `realpath`.

## What the gate does

`gate-check.sh` is registered as a `PreToolUse` hook matching
`Edit|Write|MultiEdit|NotebookEdit`. While a quality gate is open with findings
that have not been verified by execution, the hook returns
`permissionDecision: deny` and the edit does not happen. The reason it prints
names the specific finding ids that are blocking and the exact command to clear
them.

The hook **fails open**: a missing `jq`, malformed state, or any unexpected
error allows the edit through. It must never be the reason ordinary editing
gets stuck. It also exempts its own state directory, `/tmp`, and any path
containing `scratchpad`, so a repro script can be written while the gate is
closed against application code.

## The cycle

### Open

```
adze-gate open --target <description> --finding <ID>:<FILE>:<SUMMARY> [--finding ...]
```

Records the findings and flips the state to `findings-open`. From this moment
edits are blocked. `FILE` is normalized to an absolute path; it is the file the
verification will later be bound to.

### Verify

```
adze-gate verify <ID> --repro <path> [--proven-safe | --inconclusive] [--reason <text>]
```

This **executes** the repro. It does not take your word for the verdict.

- Default (**Confirmed**) requires the repro to exit **non-zero**. A repro that
  passes does not demonstrate a defect, so a zero exit is rejected outright.
- `--proven-safe` requires the repro to exit **zero**. This drops the finding
  and explicitly does *not* authorize edits to the file — nothing is being
  fixed, the concern was shown to be unfounded.
- `--inconclusive` requires `--reason` and keeps the finding blocking. An
  inconclusive verification without a documented reason is not a verification.

The repro is run directly if executable, otherwise via `bash` for `.sh` and
`python3` for `.py`. Anything else is refused rather than guessed at.

### Digest binding

Every Confirmed verification records the SHA-256 of the finding's file at the
moment of verification. The hook re-checks that digest on each edit and denies
on mismatch. A verification therefore goes stale the instant the file changes —
you cannot verify a finding once and then keep editing the file indefinitely on
the strength of it. Proven-safe entries are exempt, since they authorize no
edits and so have nothing to bind.

### Confirm the fix

```
adze-gate confirm-fix <ID>
```

Re-runs the repro that was recorded for that finding and requires it to now
**pass** (exit zero). This is Step 4d.5 of the workflow: it closes the red-green
loop that `verify` opened. If the repro still fails, nothing is recorded and the
work goes back to the fix step.

A green repo test suite does not substitute for this. Those tests did not catch
the defect in the first place, so their passing says nothing about whether it is
gone.

### Close

```
adze-gate close
```

Archives the cycle to `history/<timestamp>/`. It **refuses** while any Confirmed
finding has no confirmed fix.

### Status and override

```
adze-gate status
adze-gate override --reason <text>
```

`status` prints every finding with its verdict, whether its fix has been
re-verified, and whether its digest is still current.

`override` is the escape hatch. It clears the gate without verifications,
prints a loud banner, and appends a permanent timestamped entry with your reason
to `override-log.txt`. It is deliberately noisy and deliberately durable.

## Installation

The files here are the canonical source. The live copies belong at
`~/.claude/adze-bonch/`:

1. Copy `adze-gate` and `gate-check.sh` to `~/.claude/adze-bonch/`, keeping the
   executable bit on both.
2. Put `adze-gate` on `PATH` (a symlink from `~/.local/bin/adze-gate` works).
3. Register `gate-check.sh` as a `PreToolUse` hook in `~/.claude/settings.json`,
   matching `Edit|Write|MultiEdit|NotebookEdit`.

Runtime state (`gate-state.json`, `gate-verdicts.json`, `history/`,
`override-log.txt`) is created in `~/.claude/adze-bonch/` on first use and is
not part of this directory.

## Known limitations

Two, stated plainly because both are real and neither is fixed.

**No concurrency control.** `gate-state.json` and `gate-verdicts.json` have no
lock around their read-modify-write cycles. The tool assumes a single writer.
Two drivers operating the gate at once can interleave a read-modify-write and
corrupt or mask each other's state. Fixing this needs a `flock` (or equivalent)
around every state mutation in `adze-gate`, and probably around
`gate-check.sh`'s reads too.

**The hook binds only the main session's tool calls.** It intercepts `Edit`,
`Write`, `MultiEdit`, and `NotebookEdit` in the session it is registered for. It
does **not** constrain a subagent's tool calls, and it does not see anything
done through `Bash` — a `sed -i` or a heredoc write sails straight past it. The
gate is a discipline aid for the main driver, not a sandbox.
