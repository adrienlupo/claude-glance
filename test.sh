#!/bin/bash

DIR="$HOME/.claude-glance/sessions"
mkdir -p "$DIR"

echo "=== Phase 1: Register 3 sessions ==="
for i in test1 test2 test3; do
    echo "{\"session_id\":\"$i\",\"cwd\":\"/tmp/project-$i\",\"hook_event_name\":\"SessionStart\"}" | bash hooks/hook.sh
    sleep 0.5
done
echo "3 sessions registered (all idle/done)"
sleep 2

echo ""
echo "=== Phase 2: Mixed states ==="
echo '{"session_id":"test1","cwd":"/tmp/project-test1","hook_event_name":"UserPromptSubmit"}' | bash hooks/hook.sh
echo '{"session_id":"test2","cwd":"/tmp/project-test2","hook_event_name":"Notification"}' | bash hooks/hook.sh
echo "test1=busy, test2=waiting, test3=idle"
sleep 3

echo ""
echo "=== Phase 3: All back to idle ==="
for i in test1 test2 test3; do
    echo "{\"session_id\":\"$i\",\"cwd\":\"/tmp/project-$i\",\"hook_event_name\":\"Stop\"}" | bash hooks/hook.sh
done
echo "All sessions idle"
sleep 2

echo ""
echo "=== Phase 4: Cleanup ==="
rm -f "$DIR"/test*.json
echo "Test sessions removed"
echo ""
echo "Done."
