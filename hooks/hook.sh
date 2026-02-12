#!/bin/bash

DIR="$HOME/.claude-glance/sessions"
mkdir -p "$DIR"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')

if [ -z "$SESSION_ID" ] || [ -z "$EVENT" ]; then
    exit 0
fi

case "$EVENT" in
    SessionStart)       STATUS="idle" ;;
    UserPromptSubmit)   STATUS="busy" ;;
    PreToolUse)         STATUS="busy" ;;
    Stop)               STATUS="idle" ;;
    Notification)       STATUS="waiting" ;;
    PostToolUseFailure)
        IS_INTERRUPT=$(echo "$INPUT" | jq -r '.is_interrupt // false')
        if [ "$IS_INTERRUPT" = "true" ]; then
            STATUS="interrupted"
        else
            exit 0
        fi
        ;;
    *)                  exit 0 ;;
esac

TS=$(date +%s)
TMP="$DIR/${SESSION_ID}.tmp"
TARGET="$DIR/${SESSION_ID}.json"

PID="${PPID:-0}"
TTY=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')

for f in "$DIR"/*.json; do
    [ "$f" = "$TARGET" ] && continue
    [ -f "$f" ] && OLD_PID=$(jq -r '.pid // 0' "$f" 2>/dev/null) && [ "$OLD_PID" = "$PID" ] && rm -f "$f"
done

jq -n --arg cwd "$CWD" --arg status "$STATUS" --argjson ts "$TS" --argjson pid "$PID" --arg tty "$TTY" \
    '{cwd: $cwd, status: $status, ts: $ts, pid: $pid, tty: $tty}' > "$TMP"
mv "$TMP" "$TARGET"
