# azagatti-skills

[![release](https://img.shields.io/github/v/release/AZagatti/azagatti-skills?sort=semver)](https://github.com/AZagatti/azagatti-skills/releases)
[![ci](https://github.com/AZagatti/azagatti-skills/actions/workflows/ci.yml/badge.svg)](https://github.com/AZagatti/azagatti-skills/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/github/license/AZagatti/azagatti-skills)](LICENSE)
[![skills.sh](https://skills.sh/b/AZagatti/azagatti-skills)](https://skills.sh/AZagatti/azagatti-skills)

Andre Zagatti's [Claude Code](https://code.claude.com) **skills** — a growing collection, grouped into **plugins by category**. Each skill is empirically verified against the real tool it documents, not written from assumption.

The first (and currently only) plugin is **`headless-clis`**. Future categories will be added as additional plugins in the same marketplace.

---

## Plugin: `headless-clis`

Drive other coding CLIs **headlessly** — so one agent can delegate a self-contained task to another model's CLI, get a **cross-vendor second opinion**, run cheaper/parallel work, or produce structured output for scripts and CI. Start with **`headless-delegate`** (the router) if you're not sure which CLI to use.

| Skill | CLI | Headless entry | Tested | Headline gotcha |
|-------|-----|----------------|--------|-----------------|
| [**headless-delegate**](skills/headless-delegate/SKILL.md) | — (router) | picks one of the below | — | cross-vendor is the value; delegating a model to itself just adds cost |
| [**codex-exec**](skills/codex-exec/SKILL.md) | OpenAI Codex | `codex exec` | `codex 0.144.3` | `-C` must precede `review`; reasoning off by default |
| [**claude-headless**](skills/claude-headless/SKILL.md) | Claude Code | `claude -p` | `claude 2.1.208` | writes denied by default → check `permission_denials` |
| [**grok-headless**](skills/grok-headless/SKILL.md) | xAI Grok Build | `grok -p` | `grok 0.2.93` | `-p` takes the prompt as its value; review needs `--always-approve` |
| [**agy-headless**](skills/agy-headless/SKILL.md) | Google Antigravity | `agy -p` | `agy 1.1.2` | no cwd → `--add-dir`; hangs (not errors) on unapproved tools |

*(Last verified 2026-07. CLI behavior drifts — each skill points you at runtime `<cli> models` as the source of truth.)*

**→ [Cross-CLI comparison & chooser](docs/cli-comparison.md)** · **[Safety & blast radius](docs/safety.md)**

## Quick start

```bash
# 1. install (any of the options below)
# 2. sanity-check which delegate CLIs you have (name, version, safe starter command):
./scripts/doctor.sh
# 3. in Claude Code, ask for a delegation — the skills route it:
#    "get a second opinion from Codex on this diff"  → codex-exec
#    "review my PR with grok"                          → grok-headless
```

## Install

### Recommended: skills.sh (works with every agent)

```bash
npx skills add AZagatti/azagatti-skills
```

The [skills.sh](https://skills.sh/AZagatti/azagatti-skills) CLI installs into whichever agent you use (Claude Code, Codex, Grok, Antigravity, Cursor, …) and bootstraps the directory page + the badge above (populated by install telemetry — live after the first `npx skills add`). Great for per-project use.

### Claude Code (native marketplace)

```
/plugin marketplace add AZagatti/azagatti-skills
/plugin install headless-clis@azagatti-skills
```

Update with `/plugin marketplace update azagatti-skills`. Loads from the plugin cache — doesn't touch `~/.claude/skills/`.

### Any agent, via symlink

`install.sh` clones-and-symlinks so the repo stays the single source of truth. Point it at the target agent's skills dir with `TARGET`:

```bash
git clone https://github.com/AZagatti/azagatti-skills ~/dev/azagatti-skills
~/dev/azagatti-skills/install.sh                                  # → ~/.claude/skills  (default)
TARGET=~/.codex/skills            ~/dev/azagatti-skills/install.sh   # OpenAI Codex
TARGET=~/.grok/skills             ~/dev/azagatti-skills/install.sh   # xAI Grok
TARGET=~/.gemini/antigravity/skills ~/dev/azagatti-skills/install.sh # Google Antigravity
```

Update: `./update.sh`. Uninstall: `./uninstall.sh`.

> Codex, Grok, and Antigravity each also have a **native plugin command** that can install this repo from git — `codex plugin marketplace add …`, `grok plugin install <git-url|path>`, `agy plugin install <plugin@marketplace>` (or `agy plugin import claude` to pull in what Claude Code already has). See each tool's own docs for exact syntax; the `TARGET=` symlink above is the tool-agnostic path.

## Why these exist

They aren't wrappers — they don't run the CLIs for you. They're **knowledge**: each was built by running the target CLI dozens of times and recording what really happens (e.g. "a Grok review that runs `git diff` returns `Cancelled` and no-ops under default perms — pass `--always-approve`"; "Antigravity ignores your cwd and writes to a scratch dir unless you `--add-dir`"). A fresh agent gets it right the first time instead of rediscovering the gotchas.

## Versioning & releases

Versioning is **plugin-level** (`version` in `.claude-plugin/plugin.json`, mirrored in `marketplace.json`), tracked in [`CHANGELOG.md`](CHANGELOG.md) ([Keep a Changelog](https://keepachangelog.com) + [SemVer](https://semver.org)).

**Automated with [release-please](https://github.com/googleapis/release-please)** — commit to `main` with [Conventional Commits](https://www.conventionalcommits.org) (`feat:` → minor, `fix:` → patch, `feat!:` → major). The action opens a release PR that bumps both manifests + the changelog; merging it tags `vX.Y.Z` and publishes the GitHub Release. Manual fallback: `scripts/release.sh x.y.z`.

**CI** ([`ci.yml`](.github/workflows/ci.yml)) validates every PR: `scripts/validate-skills.py` checks skill frontmatter, anchor resolution, marketplace registration, and version sync; separate steps run JSON parsing, ShellCheck on the shell scripts, and a markdown link check.

## Layout

```
azagatti-skills/
├── .claude-plugin/{marketplace.json, plugin.json}   # marketplace (generic) → headless-clis plugin
├── .github/{workflows/{ci,release-please}.yml, ISSUE_TEMPLATE/, dependabot.yml, CODEOWNERS, ...}
├── scripts/{validate-skills.py, doctor.sh, new-skill.sh, release.sh}
├── template/{SKILL.md, reference.md}                # scaffold for new skills
├── docs/{cli-comparison.md, safety.md}
├── install.sh / update.sh / uninstall.sh
├── CHANGELOG.md · CONTRIBUTING.md · SECURITY.md · CODE_OF_CONDUCT.md
└── skills/
    ├── headless-delegate/  {SKILL.md}
    ├── codex-exec/         {SKILL.md, reference.md}
    ├── claude-headless/    {SKILL.md, reference.md}
    ├── grok-headless/      {SKILL.md, reference.md}
    └── agy-headless/       {SKILL.md, reference.md}
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The bar is **empirical accuracy** — verify every behavioral claim against the real CLI and note the version. Use `scripts/new-skill.sh <name> "<description>"` to scaffold, and `python3 scripts/validate-skills.py` before opening a PR.

## License

MIT — see [LICENSE](LICENSE).
