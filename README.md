# Claude Glance

A macOS menu bar app that shows the real-time status of your Claude Code sessions. See at a glance whether Claude is idle, busy, or waiting for input -- without switching windows.

## Prerequisites

- macOS 14+ (Sonoma) on Apple Silicon
- [jq](https://jqlang.github.io/jq/) (used by the hook script)
  ```
  brew install jq
  ```

## Installation

### Homebrew

```bash
brew install --cask adrienlupo/tap/claude-glance
```

Since the app is not code-signed, macOS Gatekeeper will block it on first launch. Allow it with:

```bash
xattr -cr /Applications/ClaudeGlance.app
```

### From source

```bash
git clone https://github.com/adrienlupo/claude-glance.git
cd claude-glance
make install
```

Both methods install `ClaudeGlance.app` to `/Applications/` and hook scripts to `~/.claude-glance/hooks/`.

## Hook Setup

Claude Glance relies on Claude Code hooks to track session status. Add the following to your `~/.claude/settings.json`:

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


### What each hook does

| Event | Status set |
|---|---|
| `SessionStart` | **idle** -- a new session has started |
| `UserPromptSubmit` | **busy** -- Claude is processing a prompt |
| `PreToolUse` | **busy** -- Claude is about to use a tool |
| `Stop` | **idle** -- Claude has finished responding |
| `Notification` | **waiting** -- Claude needs your attention |

## Uninstall

1. Remove the hook entries from `~/.claude/settings.json`
2. Remove the app:
   - **Homebrew:** `brew uninstall claude-glance`
   - **Manual:**
     ```bash
     rm -rf /Applications/ClaudeGlance.app
     rm -rf ~/.claude-glance
     ```
