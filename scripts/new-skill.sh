#!/usr/bin/env bash
# Scaffold a new skill from template/ and register it in the marketplace.
# Usage: scripts/new-skill.sh <kebab-name> "<one-line description>"
set -euo pipefail

NAME="${1:-}"; DESC="${2:-A new skill. Triggers on: TODO.}"
[[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "usage: $0 <kebab-name> \"<description>\""; exit 1; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO/skills/$NAME"
[ -e "$DEST" ] && { echo "skills/$NAME already exists"; exit 1; }

mkdir -p "$DEST"
# template files use a .tmpl suffix so scanners (skills.sh) don't discover the
# scaffold itself as a skill — the CLI keys on any file literally named *SKILL.md.
for f in SKILL.md reference.md; do
  sed -e "s/SKILL_NAME/$NAME/g" "$REPO/template/$f.tmpl" > "$DEST/$f"
done
# fill the description line — json.dumps() gives a valid double-quoted YAML scalar;
# the callable replacement avoids re.sub() interpreting backslashes in DESC.
python3 - "$DEST/SKILL.md" "$DESC" <<'PY'
import re, sys, json
p, desc = sys.argv[1], sys.argv[2]
t = open(p).read()
t = re.sub(r'^description:.*$', lambda _m: 'description: ' + json.dumps(desc), t, count=1, flags=re.M)
open(p, 'w').write(t)
PY

# register in marketplace.json (append to the first plugin's skills array)
tmp=$(mktemp)
jq --arg s "./skills/$NAME" '.plugins[0].skills += [$s]' "$REPO/.claude-plugin/marketplace.json" > "$tmp" \
  && mv "$tmp" "$REPO/.claude-plugin/marketplace.json"

echo "Created skills/$NAME and registered it. Next:"
echo "  1. Write the skill (verify against the real CLI, note versions)."
echo "  2. python3 scripts/validate-skills.py"
