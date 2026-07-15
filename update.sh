#!/usr/bin/env bash
# Pull the latest skills and re-link them.
# Usage: ./update.sh   (or TARGET=~/.codex/skills ./update.sh)
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"
git pull --ff-only
"$REPO_DIR/install.sh"
