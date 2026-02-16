#!/bin/bash

DIR="$HOME/.claude-glance/sessions"
mkdir -p "$DIR"
chmod 700 "$DIR"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')

if [ -z "$SESSION_ID" ] || [ -z "$EVENT" ]; then
    exit 0
fi

TARGET="$DIR/${SESSION_ID}.json"
LOCK="$DIR/${SESSION_ID}.lock"

acquire_lock() {
    local retries=0
    while ! mkdir "$LOCK" 2>/dev/null; do
        retries=$((retries + 1))
        if [ "$retries" -gt 10 ]; then
            local lock_mod
            lock_mod=$(stat -f %m "$LOCK" 2>/dev/null || echo 0)
            if [ $(( $(date +%s) - lock_mod )) -gt 2 ]; then
                rmdir "$LOCK" 2>/dev/null && continue
            fi
            exit 0
        fi
        sleep 0.01
    done
}

acquire_lock
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

case "$EVENT" in
    SessionStart)              STATUS="idle" ;;
    UserPromptSubmit)          STATUS="busy" ;;
    PreToolUse|PostToolUse)    STATUS="busy" ;;
    Stop)
        if [ -f "$TARGET" ]; then
            CURRENT=$(jq -r '.status // ""' "$TARGET" 2>/dev/null)
            if [ "$CURRENT" = "waiting" ]; then
                exit 0
            fi
        fi
        STATUS="idle" ;;
    Notification)
        if [ -f "$TARGET" ]; then
            CURRENT=$(jq -r '.status // ""' "$TARGET" 2>/dev/null)
            CURRENT_EVENT=$(jq -r '.event // ""' "$TARGET" 2>/dev/null)
            if [ "$CURRENT" = "busy" ] && [ "$CURRENT_EVENT" = "UserPromptSubmit" ]; then
                exit 0
            fi
        fi
        STATUS="waiting" ;;
    *)                         exit 0 ;;
esac

TS=$(date +%s)
TMP="$DIR/${SESSION_ID}.${$}.tmp"

PID="${PPID:-0}"
TTY=$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')

for f in "$DIR"/*.json; do
    [ "$f" = "$TARGET" ] && continue
    if [ -f "$f" ]; then
        OLD_PID=$(jq -r '.pid // 0' "$f" 2>/dev/null)
        if [ "$OLD_PID" = "$PID" ]; then
            rm -f "$f"
        fi
    fi
done

umask 077
jq -n --arg cwd "$CWD" --arg status "$STATUS" --argjson ts "$TS" \
    --argjson pid "$PID" --arg tty "$TTY" --arg event "$EVENT" \
    '{cwd: $cwd, status: $status, ts: $ts, pid: $pid, tty: $tty, event: $event}' > "$TMP"
mv "$TMP" "$TARGET"
