#!/usr/bin/env bash
# Preflight for the headless-CLI skills: which delegate CLIs are installed, their
# version, whether they're authenticated, and the safest starter command for each.
# Read-only — makes no changes, spawns no agent.
set -uo pipefail

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
no() { printf '  \033[31m✗\033[0m %s\n' "$1"; }
info() { printf '      %s\n' "$1"; }

check() { # name  bin  version-cmd  auth-hint  safe-template
  local name="$1" bin="$2" vcmd="$3" auth="$4" tmpl="$5"
  printf '\n\033[1m%s\033[0m\n' "$name"
  if ! command -v "$bin" >/dev/null 2>&1; then
    no "$bin not on PATH"; info "install, then: $auth"; return
  fi
  ok "$bin — $($vcmd 2>/dev/null | head -1)"
  info "safe start: $tmpl"
}

echo "Headless-CLI delegation doctor"
check "codex-exec (OpenAI)"        codex "codex --version" \
  "codex login" \
  'codex exec -s read-only -C <repo> "<goal>"'
check "claude-headless (Anthropic)" claude "claude --version" \
  "claude / then /login" \
  'claude -p "<task>" --output-format json | jq -r .result'
check "grok-headless (xAI)"         grok  "grok --version" \
  "grok login" \
  'grok --cwd <repo> -p "<task>"   # prompt is -p'\''s value'
check "agy-headless (Antigravity)"  agy   "agy --version" \
  "agy login" \
  'agy --add-dir <repo> --print-timeout 3m -p "<task>"   # no cwd → --add-dir'

echo
echo "Model lists are account/version-specific — verify at runtime:"
echo "  codex: (see reference)   grok models   agy models"
echo "Full safety rules: docs/safety.md · comparison: docs/cli-comparison.md"
