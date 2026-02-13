#!/bin/bash

DIR="$HOME/.claude-glance/sessions"
INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
[ -z "$SESSION_ID" ] && exit 0

PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)
[ -z "$PCT" ] && exit 0

mkdir -p "$DIR"
echo "$PCT" > "$DIR/${SESSION_ID}.ctx"
