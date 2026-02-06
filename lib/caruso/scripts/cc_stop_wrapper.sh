#!/bin/bash
# Translates Claude Code stop hook I/O to Cursor format.
#
# INPUT translation (stdin):
#   Cursor may pass transcript_path: null. CC hooks that read the transcript
#   would bail out. We provide a minimal dummy transcript so the hook can
#   proceed past transcript gates (completion promise won't match, but the
#   core loop/block logic still works).
#
# OUTPUT translation (stdout):
#   CC: exit 2 + stderr reason       -> block
#   CC: exit 0 + {"decision":"block","reason":"..."} -> block
#   Cursor: exit 0 + {"followup_message":"..."} -> continue with message
#   Cursor: exit 0 + no output                 -> allow stop
#
# Usage: cc_stop_wrapper.sh <original-script> [args...]

set -uo pipefail

SCRIPT="$1"
shift

STDERR_TMP=$(mktemp) || exit 1
FAKE_TRANSCRIPT=""
trap 'rm -f "$STDERR_TMP" "$FAKE_TRANSCRIPT"' EXIT

# Read and patch stdin: ensure transcript_path points to a readable file
INPUT=$(cat)
if [ -n "$INPUT" ] && command -v jq >/dev/null 2>&1; then
  TP=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
  if [ -z "$TP" ] || [ "$TP" = "null" ] || [ ! -f "$TP" ]; then
    FAKE_TRANSCRIPT=$(mktemp) || exit 1
    echo '{"role":"assistant","message":{"content":[{"type":"text","text":"(transcript not available)"}]}}' > "$FAKE_TRANSCRIPT"
    INPUT=$(echo "$INPUT" | jq --arg tp "$FAKE_TRANSCRIPT" '.transcript_path = $tp')
  fi
fi

OUTPUT=$(echo "$INPUT" | "$SCRIPT" "$@" 2>"$STDERR_TMP")
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
