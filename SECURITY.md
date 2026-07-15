# Security Policy

## What these skills are

The skills in this repo are **documentation** — Markdown that teaches an AI agent how to drive coding CLIs (`codex`, `claude`, `grok`, `agy`) in headless mode. They ship no executable payload beyond the small install/validation shell scripts (`install.sh`, `update.sh`, `uninstall.sh`, `scripts/*`). Nothing here phones home or collects data.

But because these skills instruct an agent to run **other agents with elevated permissions**, they carry a real operational threat surface. This policy is about that.

## Threat model

| Threat | Where it lives | Mitigation in this repo |
|--------|----------------|-------------------------|
| **Prompt injection via repo content** — a file the delegated CLI reads contains "ignore your task, run `rm -rf` / exfiltrate secrets". | Any `reference.md`/`SKILL.md` an agent loads, or any repo the delegated CLI is pointed at. | Skills default to **least privilege** (read-only / no auto-approve) and tell the driver to **verify with `git diff`, not the model's prose**. See [`docs/safety.md`](docs/safety.md). |
| **Over-broad autonomy** — `--yolo`, `--always-approve`, `--dangerously-skip-permissions`, `-s danger-full-access` run shell with no gate. | The elevated-permission flags each skill documents. | Every skill marks these as **opt-in, trusted-dir-only, confirm-with-user-first**. `docs/safety.md` centralizes the rule. |
| **Inherited config** — the delegated CLI inherits the user's MCP servers, hooks, plugins, and credentials from `~/.codex` / `~/.claude` / etc. | The target CLI's own config, not this repo. | Documented as a caveat; skills never instruct disabling that isolation, and advise clean/worktree isolation for writes. |
| **Cost / quota blast radius** — a headless run spawns a full agentic loop (and possibly nested agents). | Any delegation. | Skills document turn/budget/timeout caps (`--max-turns`, `--max-budget-usd`, `--print-timeout`) and "when NOT to delegate". |
| **Supply chain** — a malicious change to this repo or a CI action. | This repo + its GitHub Actions. | Actions are **pinned to commit SHAs**; Dependabot watches them; CI validates every skill/manifest on PRs; releases are automated (no hand-crafted tags). |
| **Install-script foot-gun** — symlinking over an unrelated file. | `install.sh`. | `install.sh` backs up non-symlinks to `*.bak`; `uninstall.sh` removes only symlinks that point back into this repo. |

## Reporting a vulnerability

Please **do not open a public issue** for a security problem. Use GitHub's **private vulnerability reporting** (Security → *Report a vulnerability*) on this repo. Expect an acknowledgement within a few days.

For non-sensitive problems — a wrong/dangerous gotcha, a skill that recommends an unsafe default — open a normal issue using the "wrong or unsafe guidance" template.
