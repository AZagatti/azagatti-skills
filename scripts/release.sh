#!/usr/bin/env bash
# Cut a release: bump the version in plugin.json + marketplace.json, tag, push, and
# create a GitHub Release from the matching CHANGELOG section.
#
# Usage:
#   scripts/release.sh 0.2.0
#
# Prereqs: clean working tree, `jq` and `gh` installed, a CHANGELOG.md "## [x.y.z]" section.
set -euo pipefail

VERSION="${1:-}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage: $0 X.Y.Z (semver)"; exit 1; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"
[ -z "$(git status --porcelain)" ] || { echo "working tree not clean — commit or stash first"; exit 1; }
grep -q "## \[$VERSION\]" CHANGELOG.md || { echo "CHANGELOG.md has no '## [$VERSION]' section — add it first"; exit 1; }

echo "Bumping to $VERSION…"
tmp=$(mktemp)
jq --arg v "$VERSION" '.version = $v'          .claude-plugin/plugin.json     > "$tmp" && mv "$tmp" .claude-plugin/plugin.json
jq --arg v "$VERSION" '.metadata.version = $v' .claude-plugin/marketplace.json > "$tmp" && mv "$tmp" .claude-plugin/marketplace.json

git add .claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md
git commit -m "chore(release): v$VERSION"
git tag -a "v$VERSION" -m "v$VERSION"
git push origin main "v$VERSION"

# Release notes = the CHANGELOG section for this version.
notes=$(awk "/^## \[$VERSION\]/{f=1;next} /^## \[/{f=0} f" CHANGELOG.md)
gh release create "v$VERSION" --title "v$VERSION" --notes "$notes"
echo "Released v$VERSION → https://github.com/AZagatti/azagatti-skills/releases/tag/v$VERSION"
