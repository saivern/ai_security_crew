#!/bin/bash
# One-time setup: installs the UserPromptSubmit hook into ~/.claude/settings.json.
# Safe to run multiple times — will not add duplicate entries.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_SCRIPT="$REPO_DIR/scripts/security_hook.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

chmod +x "$HOOK_SCRIPT"

mkdir -p "$(dirname "$SETTINGS_FILE")"
[ -f "$SETTINGS_FILE" ] || echo '{}' > "$SETTINGS_FILE"

python3 - "$SETTINGS_FILE" "$HOOK_SCRIPT" <<'PYEOF'
import json
import os
import sys
import tempfile

settings_path, hook_script = sys.argv[1], sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

hook_entry = {"type": "command", "command": hook_script}
hook_block = {"hooks": [hook_entry]}

hooks = settings.setdefault("hooks", {})
ups_hooks = hooks.setdefault("UserPromptSubmit", [])

if not any(hook_script in str(h) for h in ups_hooks):
    ups_hooks.append(hook_block)

    settings_dir = os.path.dirname(os.path.abspath(settings_path))
    with tempfile.NamedTemporaryFile("w", dir=settings_dir, delete=False, suffix=".tmp") as tmp:
        json.dump(settings, tmp, indent=2)
        tmp_path = tmp.name
    os.replace(tmp_path, settings_path)

    # Validate the file is still valid JSON
    with open(settings_path) as f:
        json.load(f)

    print(f"✓ Hook registered in {settings_path}")
else:
    print(f"✓ Hook already registered in {settings_path} — no changes made")
PYEOF

echo "✓ scripts/security_hook.sh is executable"
echo ""
echo "Restart Claude Code for the hook to take effect."
