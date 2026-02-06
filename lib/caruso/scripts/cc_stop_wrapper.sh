#!/bin/bash
# Translates Claude Code stop hook output to Cursor format.
#
# CC stop hooks communicate via:
#   Exit 2 + stderr reason       -> block (continue conversation)
#   Exit 0 + {"decision":"block","reason":"..."} -> block
#   Exit 0 + anything else       -> allow stop
#
# Cursor stop hooks expect:
#   Exit 0 + {"followup_message":"..."} -> continue with message
#   Exit 0 + no output                 -> allow stop
#
# Usage: cc_stop_wrapper.sh <original-script> [args...]

set -uo pipefail

SCRIPT="$1"
shift

STDERR_TMP=$(mktemp) || exit 1
trap 'rm -f "$STDERR_TMP"' EXIT

OUTPUT=$("$SCRIPT" "$@" 2>"$STDERR_TMP")
EXIT_CODE=$?

# CC exit 2 = block with stderr reason
if [ $EXIT_CODE -eq 2 ]; then
  REASON=$(cat "$STDERR_TMP")
  if [ -n "$REASON" ] && command -v jq >/dev/null 2>&1; then
    jq -n --arg msg "$REASON" '{"followup_message": $msg}'
  fi
  exit 0
fi

# CC exit 0 + JSON {"decision":"block"} -> translate to followup_message
if [ $EXIT_CODE -eq 0 ] && [ -n "$OUTPUT" ] && command -v jq >/dev/null 2>&1; then
  DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty' 2>/dev/null)
  if [ "$DECISION" = "block" ]; then
    REASON=$(echo "$OUTPUT" | jq -r '.reason // empty' 2>/dev/null)
    [ -n "$REASON" ] && jq -n --arg msg "$REASON" '{"followup_message": $msg}'
    exit 0
  fi
fi

# Pass through anything else unchanged
[ -n "$OUTPUT" ] && echo "$OUTPUT"
exit $EXIT_CODE
