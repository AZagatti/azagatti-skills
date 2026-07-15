# azagatti-skills

A small collection of [Claude Code](https://code.claude.com) **skills** for driving other coding CLIs **headlessly** — so one agent can delegate a self-contained task to another model's CLI, get a cross-vendor second opinion, or produce structured output for scripts and CI.

Each skill is the distilled, **empirically-verified** manual for one CLI's non-interactive (`-p` / `exec` / `run`) mode: the exact invocation, the permission model (what silently no-ops), the output shape, and the model/effort matrix — the parts agents forget or get subtly wrong.

## Skills

| Skill | CLI | Headless entry | Notes |
|-------|-----|----------------|-------|
| **`codex-exec`** | OpenAI Codex (`codex`) | `codex exec` | Agentic; `-C` workspace, sandbox modes, `review --base`, resume, JSON events, model reasoning-effort (none/low/…/max). |
| **`claude-headless`** | Claude Code (`claude`) | `claude -p` | Permission model (writes denied by default → `permission_denials`), `--output-format json`, model + `--effort` per-model support. |
| **`grok-headless`** | xAI Grok Build (`grok`) | `grok -p` | The `-p`-takes-the-prompt-as-its-value gotcha, default denies writes (`stopReason: Cancelled`), account-scoped models, per-model effort/reasoning-off. |
| **`agy-headless`** | Google Antigravity (`agy`) | `agy -p` | Multi-vendor (Gemini/Claude/GPT-OSS behind one login); **no cwd — use `--add-dir`**; effort baked into the model name; plain-text only. |

Every skill is a folder under [`skills/`](./skills) with a concise `SKILL.md` entry point plus a `reference.md` (progressive disclosure), following the [Agent Skills](https://github.com/anthropics/skills) convention.

## Install

### Option A — plugin marketplace (recommended)

Versioned via git, no symlinks, works on any machine. In Claude Code:

```
/plugin marketplace add AZagatti/azagatti-skills
/plugin install headless-clis@azagatti-skills
```

Update later with `/plugin marketplace update azagatti-skills`. The skills load from Claude Code's plugin cache — they don't touch your personal `~/.claude/skills/`.

### Option B — symlink (for local editing / other providers)

Clone once and symlink each skill into your skills dir, so `git pull` updates them and edits flow straight back to the repo:

```bash
git clone https://github.com/AZagatti/azagatti-skills ~/dev/azagatti-skills
~/dev/azagatti-skills/install.sh              # symlinks into ~/.claude/skills/
# other providers: TARGET=~/.codex/skills ~/dev/azagatti-skills/install.sh
```

`install.sh` symlinks (not copies), so the repo stays the single source of truth.
- **Update:** `./update.sh` (git pull + re-link).
- **Uninstall:** `./uninstall.sh` (removes only the symlinks pointing back into this repo).

## Why these exist

These aren't wrappers — they don't run the CLIs for you. They're **knowledge**: each was built by actually running the target CLI dozens of times and recording what really happens (e.g. "a Grok review that runs `git diff` returns `Cancelled` and no-ops under default perms — pass `--always-approve`"; "Antigravity ignores your cwd and writes to a scratch dir unless you `--add-dir`"). The goal is that a fresh agent driving these CLIs gets it right the first time instead of rediscovering the gotchas.

## Layout

```
azagatti-skills/
├── .claude-plugin/
│   ├── marketplace.json   # makes the repo an installable marketplace
│   └── plugin.json        # the headless-clis plugin manifest (version lives here)
├── install.sh / update.sh / uninstall.sh   # symlink flow (Option B)
├── scripts/release.sh     # bump version + tag + GitHub Release
├── CHANGELOG.md
├── skills/
│   ├── codex-exec/       {SKILL.md, reference.md}
│   ├── claude-headless/  {SKILL.md, reference.md}
│   ├── grok-headless/    {SKILL.md, reference.md}
│   └── agy-headless/     {SKILL.md, reference.md}
└── README.md
```

## Versioning & releases

Versioning is **plugin-level** (one version for the whole `headless-clis` plugin, matching how [mattpocock/skills](https://github.com/mattpocock/skills) and [Flagrare/agent-skills](https://github.com/Flagrare/agent-skills) do it) — the source of truth is `version` in `.claude-plugin/plugin.json`, mirrored in `marketplace.json`. Changes are recorded in [`CHANGELOG.md`](./CHANGELOG.md) ([Keep a Changelog](https://keepachangelog.com) + [SemVer](https://semver.org)).

To cut a release: add a `## [x.y.z]` section to `CHANGELOG.md`, then run `scripts/release.sh x.y.z` — it bumps both manifests, commits, tags `vx.y.z`, pushes, and creates the GitHub Release from the changelog notes. Marketplace users get the new version on `/plugin marketplace update azagatti-skills`.

## Contributing / adding a skill

1. Add `skills/<name>/SKILL.md` (+ optional `reference.md`).
2. Append `"./skills/<name>"` to the `headless-clis` plugin's `skills` array in `.claude-plugin/marketplace.json`.
3. Verify behavior against the real CLI before documenting it — these skills earn trust by being empirical, not aspirational.

## License

MIT — see [LICENSE](./LICENSE).
