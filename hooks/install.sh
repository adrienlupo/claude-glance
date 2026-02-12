#!/bin/bash

SETTINGS="$HOME/.claude/settings.json"
HOOK_CMD="bash $HOME/.claude-glance/hooks/hook.sh"
EVENTS=("SessionStart" "UserPromptSubmit" "PreToolUse" "Stop" "Notification" "PostToolUseFailure")

mkdir -p "$(dirname "$SETTINGS")"
if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

for EVENT in "${EVENTS[@]}"; do
    FOUND=$(jq --arg cmd "$HOOK_CMD" --arg event "$EVENT" \
        '[.hooks[$event][]?.hooks[]? | select(.command == $cmd)] | length' \
        "$SETTINGS" 2>/dev/null || echo "0")

    if [ "$FOUND" = "0" ]; then
        jq --arg cmd "$HOOK_CMD" --arg event "$EVENT" \
            '.hooks[$event] = (.hooks[$event] // []) + [{"hooks": [{"type": "command", "command": $cmd}]}]' \
            "$SETTINGS" > "${SETTINGS}.tmp"
        mv "${SETTINGS}.tmp" "$SETTINGS"
        echo "Installed hook for $EVENT"
    else
        echo "Hook already installed for $EVENT"
    fi
done

echo "Done. Hooks installed in $SETTINGS"
