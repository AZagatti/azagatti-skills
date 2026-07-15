# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The version is plugin-level
(one version for the whole `headless-clis` plugin), tracked in `.claude-plugin/plugin.json`.

## [Unreleased]

## [0.1.0] — 2026-07-15

Initial release. Four headless coding-CLI skills, each verified against the real CLI.

### Added
- **`codex-exec`** — drive OpenAI Codex via `codex exec`: `-C` workspace, sandbox modes, `review --base`/`--uncommitted`, session resume, JSON events, and the per-model reasoning-effort ladder (`none`…`max`).
- **`claude-headless`** — drive Claude Code via `claude -p`: the headless permission model (writes denied by default → check `permission_denials`), `--output-format json`, and per-model `--effort` support.
- **`grok-headless`** — drive xAI Grok Build via `grok -p`: the `-p`-takes-the-prompt-as-its-value gotcha, default-denies-writes (`stopReason: Cancelled`), account-scoped model list, and per-model effort / reasoning-off (`grok-4.5` vs `grok-composer-2.5-fast`).
- **`agy-headless`** — drive Google Antigravity via `agy -p`: multi-vendor (Gemini/Claude/GPT-OSS behind one login), the **no-cwd → `--add-dir`** requirement, effort baked into the model name, and plain-text-only output.
- Installable as a Claude Code plugin marketplace (`.claude-plugin/marketplace.json` + `plugin.json`); symlink installer for local editing and other providers.

[Unreleased]: https://github.com/AZagatti/azagatti-skills/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/AZagatti/azagatti-skills/releases/tag/v0.1.0
