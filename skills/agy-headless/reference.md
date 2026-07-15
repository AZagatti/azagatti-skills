# `agy -p` (Antigravity CLI, headless / print) — full reference

`agy -p <PROMPT>` (aliases `--print` / `--prompt`) runs Google's **Antigravity CLI** non-interactively: it runs a single prompt as a full agent and prints the response, then exits. It's the headless entry point — the Antigravity analog of `claude -p` / `codex exec` / `grok -p`. Antigravity is the successor to Gemini CLI. Verified against `agy 1.1.2`.

## Mental model

`agy` is a **multi-vendor aggregator** (one Google/Antigravity login → Gemini **and** Claude **and** GPT-OSS models) and a **full agent**, not a completion. Three things that bite, all different from the other headless CLIs:

- **No cwd/`-C`/`--cwd`. `agy` works in an isolated scratch workspace by default** (`~/.gemini/antigravity-cli/scratch/`) and **cannot see the directory you launched from.** To give it your repo you MUST pass **`--add-dir <path>`** (repeatable). Without it: a task that reads your files **hangs until `--print-timeout`** ("timeout waiting for response"), and any writes land in the scratch dir, not yours. Verified: with `--add-dir <dir>` it reads and writes your files; without it, it can't.
- **Effort is baked into the model name, not a `--effort` flag.** You pick `Gemini 3.5 Flash (High)` vs `(Low)`; there is no `--reasoning-effort`.
- **Plain-text output only.** There is no `--output-format`/JSON — stdout is the response text. And `agy` can **hang** on a tool it can't auto-approve (waits for approval that never comes in headless) until the timeout — so pair agentic tasks with a permission flag (below) and a sane `--print-timeout`.

## Giving it your files: `--add-dir` (the #1 gotcha)

```bash
agy --add-dir /path/to/repo -p "read src/app.ts and explain the auth flow"
```

- `--add-dir` is **repeatable** — add multiple roots.
- There is **no working-directory flag**; `--add-dir` is how files enter the workspace. A bare `agy -p "review this repo"` launched inside a repo does **not** see that repo.
- `--project <id>` / `--new-project` scope the session to an Antigravity project; `--add-dir` is the lightweight "just mount this folder" path.

## Permissions

Headless has no human to approve tool calls, so:

| Flag | Effect |
|------|--------|
| **default** (no flag) | Tool calls that need approval **block/hang** until `--print-timeout`; the run then errors `timeout waiting for response`. Read-only reasoning is fine; agentic/file/command work stalls. |
| `--mode accept-edits` | Auto-approve file edits (verified: writes apply under `--add-dir`) |
| `--mode plan` | Plan only — no changes |
| `--dangerously-skip-permissions` | Auto-approve **all** tool permission requests (files + commands) — only in a trusted/sandboxed dir; confirm with the user first |
| `--sandbox` | Run with terminal restrictions enabled |

**Rule:** for anything beyond pure reasoning, pass `--mode accept-edits` (edits) or `--dangerously-skip-permissions` (full autonomy) **plus** `--add-dir` — otherwise the agent hangs on its first tool call and times out. Keep a bounded `--print-timeout` so a stuck run fails fast.

## Key flags

| Flag | Details |
|------|---------|
| `-p` / `--print` / `--prompt <P>` | Run a single prompt non-interactively and print the response |
| `--add-dir <DIR>` | Add a directory to the workspace (**repeatable**) — how `agy` gets your files |
| `--model <NAME>` | Model for the session — the **exact display name** from `agy models` (e.g. `"Claude Opus 4.6 (Thinking)"`, spaces/parens included) |
| `--mode <M>` | Execution mode: `accept-edits` \| `plan` |
| `--dangerously-skip-permissions` | Auto-approve all tool permission requests |
| `--sandbox` | Run in a sandbox with terminal restrictions |
| `--agent <NAME>` | Agent for this session (`agy agents` lists them) |
| `--print-timeout <DUR>` | Timeout for print-mode wait (**default `5m0s`**) — bump for long agentic runs, lower to fail fast on a hang |
| `-c` / `--continue` | Continue the most recent conversation |
| `--conversation <ID>` | Resume a previous conversation by ID |
| `-i` / `--prompt-interactive <P>` | Run an initial prompt, then stay interactive (not headless) |
| `--project <ID>` / `--new-project` | Scope to / create an Antigravity project |
| `--log-file <PATH>` | Override the CLI log path |

Subcommands: `agy models` (list models), `agy agents` (list agents), `agy plugin`, `agy update`, `agy install` (shell/env setup).

## Output

Plain text on stdout — the assistant's response. **No JSON/structured mode.** For scripting, capture stdout directly; there is no `stopReason`/`text` object like `grok -p`. To confirm a file change actually happened, `git diff` (or `ls`) the `--add-dir` path — don't trust the prose, and remember writes only land when a permission flag is set.

## Models and effort

`agy models` is the source of truth. This install exposes a **multi-vendor** set, with **reasoning effort encoded in the model name** (no separate flag):

| Model (`--model` value, verbatim) | Vendor | Effort tier (in the name) |
|-----------------------------------|--------|---------------------------|
| `Gemini 3.5 Flash (Low)` / `(Medium)` / `(High)` | Google | Low / Medium / High |
| `Gemini 3.1 Pro (Low)` / `(High)` | Google | Low / High |
| `Claude Sonnet 4.6 (Thinking)` | Anthropic | thinking on |
| `Claude Opus 4.6 (Thinking)` | Anthropic | thinking on |
| `GPT-OSS 120B (Medium)` | open-weight | Medium |

- **Selection:** `--model` takes the exact display string, e.g. `agy --model "Gemini 3.5 Flash (High)" -p "…"`. An unknown value errors and prints the valid list.
- **No `--effort` / `--reasoning-effort`** — to change effort, pick a different `(Low|Medium|High)` model variant. Effort is a ceiling scaled by task (see the other headless skills), so lower tiers only differ on hard tasks.
- The lineup drifts (Antigravity is new and Google-managed) — re-run `agy models` rather than trusting this table.

## Vision (image input)

Image support is **per-model, not a CLI feature** — and it matters most here because `agy` is multi-vendor. There is no `--image` flag: put the image under `--add-dir` and name it in the prompt; a multimodal model reads it. Some text-only models can't see images, so pick a multimodal model when the task needs vision.

## Setup / auth

- `agy` on PATH (`agy --version`); logs in with a Google/Antigravity account. `agy install` configures shell/env; `agy update` upgrades.
- Antigravity is the **successor to Gemini CLI** (which is being sunset for free/consumer users) — this is Google's current headless coding agent.
