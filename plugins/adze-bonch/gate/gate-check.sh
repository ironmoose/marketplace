#!/usr/bin/env bash
# adze-bonch quality gate — PreToolUse hook (gate-check.sh)
#
# Reads a PreToolUse payload on stdin and decides whether to allow or deny
# the pending edit based on ~/.claude/adze-bonch/gate-state.json /
# gate-verdicts.json. Always exits 0 — the decision is conveyed via the
# printed JSON (permissionDecision: deny) or by printing nothing (allow).
#
# FAILS OPEN: any internal error (missing jq, malformed JSON, unexpected
# exception) allows the edit through. This script must never be the reason
# a user's own editing gets stuck.
#
# A finding is only "covered" once a verification (adze-gate verify) has
# recorded a Confirmed or Proven-safe status for it. A Confirmed verification
# is bound to a SHA-256 digest of the file it was verified against — if that
# file changes afterward, the digest no longer matches and the gate re-closes
# for that file until it is re-verified. Proven-safe verifications drop the
# finding outright (no fix is being authorized) and are exempt from the
# digest check.

GATE_DIR="$HOME/.claude/adze-bonch"
STATE_FILE="$GATE_DIR/gate-state.json"
VERDICTS_FILE="$GATE_DIR/gate-verdicts.json"

# --- helper: fail-open exit -------------------------------------------------
fail_open() {
    local reason="$1"
    if [ -n "$reason" ]; then
        printf '{"systemMessage": "adze-bonch gate: could not evaluate gate state, allowing edit (fail-open). %s"}\n' "$reason"
    fi
    exit 0
}

# --- guard: jq must exist ---------------------------------------------------
command -v jq >/dev/null 2>&1 || fail_open "jq not found on PATH."

# --- read stdin --------------------------------------------------------------
INPUT="$(cat)" || fail_open "could not read stdin."
[ -n "$INPUT" ] || fail_open "empty stdin."

printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1 || fail_open "stdin was not valid JSON."

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)" || fail_open "could not extract tool_name."
FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || fail_open "could not extract file_path."

# --- EXEMPT PATHS ------------------------------------------------------------
GATE_DIR_EXPANDED="$HOME/.claude/adze-bonch"
if [ -n "$FILE_PATH" ]; then
    case "$FILE_PATH" in
        "$GATE_DIR_EXPANDED"/*|"$GATE_DIR_EXPANDED")
            exit 0
            ;;
        /tmp/*)
            exit 0
            ;;
        *scratchpad*)
            exit 0
            ;;
    esac
fi

# --- no gate state file at all => allow -------------------------------------
[ -f "$STATE_FILE" ] || exit 0

STATUS="$(jq -r '.status // empty' "$STATE_FILE" 2>/dev/null)" || fail_open "could not parse gate-state.json."
[ "$STATUS" = "findings-open" ] || exit 0

# --- no verdicts file at all: nothing has been verified yet -----------------
if [ ! -f "$VERDICTS_FILE" ]; then
    FINDING_IDS="$(jq -r '[.findings[].id] | join(", ")' "$STATE_FILE" 2>/dev/null)"
    [ -n "$FINDING_IDS" ] || FINDING_IDS="(unable to list finding ids)"
    FINDING_COUNT="$(jq -r '(.findings // []) | length' "$STATE_FILE" 2>/dev/null)"
    [ -n "$FINDING_COUNT" ] || FINDING_COUNT="?"
    REASON="A quality gate is open with $FINDING_COUNT finding(s), none verified ($FINDING_IDS). No repro-verification has run yet (no gate-verdicts.json exists). Next step: run \`adze-gate verify <id> --repro <path>\` for each finding (add --proven-safe if the repro instead proves the code is safe, or --inconclusive --reason \"...\" if it cannot be determined)."
    SYS_MSG="adze-bonch gate: blocking edits, findings are unverified ($FINDING_IDS). Run the repro-verifier and record verifications, or use \`adze-gate override --reason \"...\"\` to bypass."
    jq -n --arg reason "$REASON" --arg sysmsg "$SYS_MSG" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}, systemMessage: $sysmsg}' \
        2>/dev/null || fail_open "could not build deny JSON."
    exit 0
fi

# --- coverage check: every finding id must have a Confirmed or Proven-safe --
# --- verification entry (Inconclusive, or no entry at all, does NOT count) --
MISSING_IDS="$(jq -r -n \
    --slurpfile state "$STATE_FILE" \
    --slurpfile verdicts "$VERDICTS_FILE" \
    '
    ($state[0].findings // []) as $findings
    | ($verdicts[0].verdicts // []) as $vs
    | [ $findings[].id as $fid
        | select(
            ([$vs[] | select(.id == $fid and (.status == "Confirmed" or .status == "Proven-safe"))] | length) == 0
          )
        | $fid
      ]
    | join(", ")
    ' 2>/dev/null)" || fail_open "could not evaluate finding coverage."

if [ -n "$MISSING_IDS" ]; then
    REASON="A quality gate is open with findings that are not yet fully verified. Verification is missing or inconclusive for: $MISSING_IDS. Run \`adze-gate verify <id> --repro <path>\` for each (add --proven-safe if the repro proves the code is safe instead of confirming the defect)."
    SYS_MSG="adze-bonch gate: blocking edits, unverified findings ($MISSING_IDS). Run \`adze-gate verify <id> --repro <path> [--proven-safe]\`, or use \`adze-gate override --reason \"...\"\` to bypass."
    jq -n --arg reason "$REASON" --arg sysmsg "$SYS_MSG" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}, systemMessage: $sysmsg}' \
        2>/dev/null || fail_open "could not build deny JSON."
    exit 0
fi

# --- digest-binding check: a Confirmed verification is void once its file --
# --- changes. Proven-safe entries are exempt (they drop the finding rather --
# --- than authorize an edit, so there is nothing to bind to a digest).     --
if [ -n "$FILE_PATH" ]; then
    NORMALIZED_FILE_PATH="$(realpath -m "$FILE_PATH" 2>/dev/null || printf '%s' "$FILE_PATH")"

    CURRENT_DIGEST=""
    if [ -f "$NORMALIZED_FILE_PATH" ]; then
        CURRENT_DIGEST="$(sha256sum "$NORMALIZED_FILE_PATH" 2>/dev/null | awk '{print $1}')"
    fi

    STALE_IDS="$(jq -r -n \
        --slurpfile verdicts "$VERDICTS_FILE" \
        --arg target "$NORMALIZED_FILE_PATH" \
        --arg current "$CURRENT_DIGEST" \
        '[($verdicts[0].verdicts // [])[] | select(.status == "Confirmed" and .file == $target and .file_sha256 != $current) | .id] | join(", ")' \
        2>/dev/null)" || fail_open "could not evaluate digest binding."

    if [ -n "$STALE_IDS" ]; then
        REASON="The verification for $STALE_IDS was against a different version of this file ($NORMALIZED_FILE_PATH) — the file has changed since verification. Re-verify with: adze-gate verify <id> --repro <path>."
        SYS_MSG="adze-bonch gate: blocking edit, verification for $STALE_IDS is stale (file changed since verification). Re-verify with \`adze-gate verify <id> --repro <path>\`, or use \`adze-gate override --reason \"...\"\` to bypass."
        jq -n --arg reason "$REASON" --arg sysmsg "$SYS_MSG" \
            '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}, systemMessage: $sysmsg}' \
            2>/dev/null || fail_open "could not build deny JSON."
        exit 0
    fi
fi

exit 0
