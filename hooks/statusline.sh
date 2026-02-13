#!/bin/bash

DIR="$HOME/.claude-glance/sessions"
INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
[ -z "$SESSION_ID" ] && exit 0

TARGET="$DIR/${SESSION_ID}.json"
[ -f "$TARGET" ] || exit 0

PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)
[ -z "$PCT" ] && exit 0

jq --argjson pct "$PCT" '. + {context_pct: $pct}' "$TARGET" > "$DIR/${SESSION_ID}.tmp"
mv "$DIR/${SESSION_ID}.tmp" "$TARGET"
