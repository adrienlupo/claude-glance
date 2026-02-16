# Claude Glance

A macOS menu bar app that shows the real-time status of your Claude Code sessions. See at a glance whether Claude is idle, busy, or waiting for input -- without switching windows.

## Prerequisites

- macOS 14+ (Sonoma) on Apple Silicon

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/adrienlupo/claude-glance/main/install.sh | bash
```

### From source

```bash
git clone https://github.com/adrienlupo/claude-glance.git
cd claude-glance
make install
```

Since the app is not code-signed, macOS Gatekeeper will block it on first launch. Allow it with:

```bash
xattr -cr /Applications/ClaudeGlance.app
```

For local development, `make run` builds and opens the app directly from the build directory.

## Hook Setup (required)

Claude Glance does nothing on its own -- it relies on Claude Code hooks to receive session status updates. Without this step, the app will show no activity.

Add the following to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "bash $HOME/.claude-glance/hooks/hook.sh" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "bash $HOME/.claude-glance/hooks/hook.sh" }] }
    ],
    "PreToolUse": [
      { "hooks": [{ "type": "command", "command": "bash $HOME/.claude-glance/hooks/hook.sh" }] }
    ],
    "PostToolUse": [
      { "hooks": [{ "type": "command", "command": "bash $HOME/.claude-glance/hooks/hook.sh" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "bash $HOME/.claude-glance/hooks/hook.sh" }] }
    ],
    "Notification": [
      { "hooks": [{ "type": "command", "command": "bash $HOME/.claude-glance/hooks/hook.sh" }] }
    ]
  }
}
```

If you already have hooks configured, merge these entries into your existing `hooks` object.

### What each hook does

| Event | Status set |
|---|---|
| `SessionStart` | **idle** -- a new session has started |
| `UserPromptSubmit` | **busy** -- Claude is processing a prompt |
| `PreToolUse` | **busy** -- Claude is about to use a tool |
| `PostToolUse` | **busy** -- a tool has finished running |
| `Stop` | **idle** -- Claude has finished responding (unless waiting) |
| `Notification` | **waiting** -- Claude needs your attention |

## Statusline Setup

To display context window usage in the session detail view, add the following to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash $HOME/.claude-glance/hooks/statusline.sh"
  }
}
```

If you already have a statusline configured, integrate the context tracking into your existing script.

## Uninstall

1. Remove the hook entries from `~/.claude/settings.json`
2. Remove the app:
   ```bash
   rm -rf /Applications/ClaudeGlance.app
   rm -rf ~/.claude-glance
   ```
