#!/usr/bin/env bash
# Symlink each skill in this repo into a Claude Code skills directory.
# Usage:
#   ./install.sh                     # → ~/.claude/skills
#   TARGET=~/.codex/skills ./install.sh   # → another provider's skills dir
# Re-run after adding a skill. Symlinks (not copies) keep this repo the source of truth.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/skills"
TARGET="${TARGET:-$HOME/.claude/skills}"

mkdir -p "$TARGET"
echo "Linking skills from $SRC → $TARGET"

for skill in "$SRC"/*/; do
  name="$(basename "$skill")"
  link="$TARGET/$name"
  if [ -L "$link" ]; then
    rm "$link"                                  # replace an existing symlink
  elif [ -e "$link" ]; then
    echo "  ! $name exists and is NOT a symlink — backing up to $name.bak"
    mv "$link" "$link.bak"
  fi
  ln -s "$skill" "$link"
  echo "  ✓ $name"
done

echo "Done. Restart Claude Code (or your provider) to pick up the skills."
