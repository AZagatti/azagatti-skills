#!/usr/bin/env bash
# Remove the symlinks install.sh created (only symlinks pointing back into this repo).
# Usage:
#   ./uninstall.sh                       # from ~/.claude/skills
#   TARGET=~/.codex/skills ./uninstall.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/skills"
TARGET="${TARGET:-$HOME/.claude/skills}"

for skill in "$SRC"/*/; do
  name="$(basename "$skill")"
  link="$TARGET/$name"
  if [ -L "$link" ] && [ "$(readlink -f "$link")" = "$(readlink -f "$skill")" ]; then
    rm "$link"; echo "  ✓ removed $name"
  else
    echo "  - skipped $name (not a symlink into this repo)"
  fi
done
echo "Done."
