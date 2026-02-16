#!/usr/bin/env bash
set -euo pipefail

REPO="adrienlupo/claude-glance"
INSTALL_DIR="$HOME/.claude-glance"
APP_NAME="ClaudeGlance.app"
APP_DEST="/Applications/$APP_NAME"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
error() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

# --- Prerequisites ---

[[ "$(uname)" == "Darwin" ]] || error "Claude Glance only supports macOS."
[[ "$(uname -m)" == "arm64" ]] || error "Claude Glance only supports Apple Silicon (arm64)."

missing=()
for cmd in curl unzip jq; do
  command -v "$cmd" >/dev/null || missing+=("$cmd")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  error "Missing required tools: ${missing[*]}. Install them with: brew install ${missing[*]}"
fi

# --- Fetch latest release ---

info "Fetching latest release from GitHub..."
release_json=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest") \
  || error "Failed to fetch release info from GitHub API."

asset_url=$(echo "$release_json" | jq -r '.assets[] | select(.name | test("arm64\\.zip$")) | .browser_download_url') \
  || error "Failed to parse release JSON."
[[ -n "$asset_url" ]] || error "No arm64 zip asset found in the latest release."

version=$(echo "$release_json" | jq -r '.tag_name')
info "Latest version: $version"

# --- Download and extract ---

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

zip_path="$tmp_dir/claude-glance.zip"
info "Downloading $asset_url..."
curl -fsSL -o "$zip_path" "$asset_url" \
  || error "Failed to download release zip."

info "Extracting..."
unzip -qo "$zip_path" -d "$tmp_dir" \
  || error "Failed to extract zip."

# --- Install ---

if [[ -d "$APP_DEST" ]]; then
  info "Removing existing $APP_NAME from /Applications..."
  rm -rf "$APP_DEST"
fi

info "Installing $APP_NAME to /Applications..."
cp -R "$tmp_dir/$APP_NAME" "$APP_DEST"

info "Bypassing Gatekeeper quarantine..."
xattr -cr "$APP_DEST"

info "Installing hooks to $INSTALL_DIR/hooks..."
mkdir -p "$INSTALL_DIR/hooks"
cp "$tmp_dir/hooks/hook.sh" "$INSTALL_DIR/hooks/"
chmod +x "$INSTALL_DIR/hooks/hook.sh"
cp "$tmp_dir/hooks/statusline.sh" "$INSTALL_DIR/hooks/"
chmod +x "$INSTALL_DIR/hooks/statusline.sh"

# --- Done ---

printf '\n\033[1;32mClaude Glance %s installed successfully!\033[0m\n\n' "$version"

cat << 'EOF'
IMPORTANT: Claude Glance requires Claude Code hooks to function.
Add the following to your ~/.claude/settings.json:

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

Then open Claude Glance from /Applications or Spotlight.
EOF
