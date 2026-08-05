# `grok -p` (Grok Build CLI, headless / single-turn) — full reference

`grok -p <PROMPT>` (long form `--single <PROMPT>`) runs xAI's **Grok Build CLI** non-interactively: it takes a prompt, runs a full agentic turn (tools, MCP, subagents), prints the response to stdout, and exits. It's the headless/scripting entry point — the Grok analog of `claude -p` and `codex exec`. Verified against `grok 0.2.118` on 2026-08-04; re-check `grok --help`, `grok models`, and `grok update --check --json`.

## Mental model

Like `claude -p` and `codex exec`, `grok -p` is a **full agent**, not a completion — it reads files, runs shell/`git`, uses MCP servers, plugins, and subagents, as its own session (own `sessionId`, own cost). It's evidently modeled on Claude Code — the `--help` cross-references Claude flags (`--allow` ↔ `--allowedTools`, `--system-prompt-override` ↔ `--system-prompt`).

Three things that bite:

- **`-p`/`--single` takes the prompt as its *value*.** The prompt must immediately follow `-p`; put every other flag **before `-p`** or after the prompt string. `grok -p --effort low "hi"` fails with `a value is required for '--single'` (see Quoting/ordering below). This is the #1 gotcha and differs from `claude -p` (a boolean).
- **Headless cannot present an interactive approval.** Project trust, persisted settings, enterprise policy, and permission rules determine what runs. Use explicit fail-closed rules for automation and verify tool results.
- **Working directory:** use `--cwd <dir>` to point Grok at a repo (unlike `claude -p`, which uses launch cwd). It's a fresh session — name the files/paths in the prompt; Grok reads them itself.

## Argument ordering (the #1 gotcha)

`-p, --single <PROMPT>` consumes the next token as its value, and won't consume a token starting with `-`. So:

```bash
grok -p "summarize README.md"                       # ✅ prompt right after -p
grok --cwd ./repo --effort high -p "review src/"    # ✅ flags before -p
grok -p "review src/" --output-format json          # ✅ flags after the prompt value
grok -p --effort high "review src/"                 # ❌ error: --single needs a value
```

Rule: **`-p "<prompt>"` as a unit, all other flags on either side of it — never between `-p` and its prompt.**

**Quoting the prompt** (it's a shell argument, so `"`, `` ` ``, `$`, `'` inside it can break the command):

- Prompt contains `"` / `` ` `` / `$` → **single-quote it**: `grok --cwd . -p 'add a "## Notes" section'` (verified — embedded `"` is inert inside `'...'`). If it also contains a literal `'`, escape that as `'\''`.
- Long, multi-line, or every-kind-of-quote → **`--prompt-file <path>`**, which *replaces* `-p` (standalone, not combined): `printf '%s' "$PROMPT" > /tmp/p.txt && grok --cwd . --always-approve --prompt-file /tmp/p.txt` (verified). `--prompt-json <json>` takes content blocks the same way.

## Permission model (the most-forgotten part)

Headless has no human to approve tool calls. Current xAI permission modes are Ask/default, Auto/`acceptEdits`, and Always approve; use rules to make non-interactive behavior deterministic:

| Flag | Read/Grep/Glob | Write/Edit | Bash / mutating |
|------|:---:|:---:|:---:|
| **default** (no flag) | depends on trust/settings/rules | prompts become denial in headless | prompts become denial in headless |
| `--always-approve` | ✅ | ✅ | ✅ (auto-approves **all** tool calls) |
| `--permission-mode bypassPermissions` | ✅ | ✅ | ✅ |
| `--permission-mode acceptEdits` | ✅ | ✅ auto-approved | shell remains gated |
| `--permission-mode plan` | ✅ (plans only) | ❌ | ❌ |
| `--allow <RULE>` / `--deny <RULE>` | granular | granular | granular (Claude Code: `--allowedTools`/`--disallowedTools`) |

On the audited trusted project with no loaded permission rules and `yolo=false`, direct file reads and a read-only `pwd` command ran under default mode. That disproves a universal "default denies all shell" rule but does not establish what mutating commands do elsewhere. For scripts, prefer `--permission-mode dontAsk` plus narrow `--allow`/`--deny` rules. Reserve `--always-approve`/`bypassPermissions` for explicit authorization in a trusted directory.

## Key flags

| Flag | Details |
|------|---------|
| `-p, --single <PROMPT>` | Single-turn: print response and exit. **Prompt is the flag's value** (see ordering) |
| `--prompt-file <PATH>` / `--prompt-json <JSON>` | Single-turn prompt from a file / as JSON content blocks (avoids shell quoting) |
| `--output-format` | `plain` · `json` · `streaming-json` · `streaming-messages-json` |
| `-m, --model <MODEL>` | Model id (default `grok-4.5`). See Models below |
| `--reasoning-effort <E>` (alias `--effort`) | Current accepted values: `low` \| `medium` \| `high` |
| `--permission-mode <M>` | `default` · `acceptEdits` · `auto` · `dontAsk` · `bypassPermissions` · `plan` |
| `--always-approve` | Auto-approve **all** tool executions (simplest way to let writes land) |
| `--allow <RULE>` / `--deny <RULE>` | Permission allow/deny rule (Claude Code: `--allowedTools`/`--disallowedTools`) |
| `--tools <LIST>` / `--disallowed-tools <LIST>` | Allow-list / remove built-in tools (comma-separated) |
| `--disable-web-search` | Turn off web search + web fetch |
| `--sandbox <PROFILE>` | Filesystem/network sandbox profile (env `GROK_SANDBOX`) |
| `--cwd <DIR>` | Working directory Grok operates in |
| `--json-schema <SCHEMA>` | Constrain output to a JSON Schema (implies `--output-format json`) |
| `--max-turns <N>` | Cap agent turns |
| `--rules <RULES>` / `--system-prompt-override <P>` | Append rules to / replace the system prompt |
| `--agent <NAME>` / `--agents <JSON>` / `--no-subagents` | Select/define custom agents; disable subagents |
| `-c, --continue` / `-r, --resume [ID-or-title]` / `-s, --session-id <UUID>` / `--fork-session` | Continue/resume existing sessions; `--session-id` names a **new** session and only combines with resume when forking |
| `--experimental-memory` / `--no-memory` | Enable / disable cross-session memory |
| `-w, --worktree [NAME]` / `--worktree-ref <REF>` | Run in a fresh git worktree |
| `--verbatim` | Send the prompt exactly as given (no augmentation) |
| `--debug` / `--debug-file <FILE>` | Debug logging |

Subcommands: `grok models` (list account models), `grok agent {stdio,headless,serve}` (lower-level SDK harness — not the simple print mode), `grok sessions`, `grok export`, `grok inspect` (show discovered config), `grok mcp`, `grok login`/`logout`.

## Output shape

- **`plain`** (default): the response text on stdout — clean, best for piping one answer.
- **`json`**: one object. Fields include `text`, `thought`, `stopReason` (successful value observed on 0.2.118: `end_turn`), `sessionId`, `requestId`, usage, turns, and cost.
- **`streaming-json`**: newline-delimited events.

Capture just the answer: `grok -p "…" --output-format json | jq -r .text`. When a task should change files, assert `stopReason == "end_turn"` and inspect `git diff` — don't trust the `text` prose.

## Models and effort

**`grok models` is the authoritative list of built-in models for the current account.** Configured custom-model keys are also selectable. The Grok Build CLI surface is not the full xAI API catalog: passing an unavailable built-in id hard-errors, so do not copy raw API model names blindly.

This install (logged in with grok.com) currently exposes one built-in model:

| Model (from `grok models`) | Role | `--effort` levels that work | Reasoning off (`none`)? |
|----------------------------|------|-----------------------------|:---:|
| **`grok-4.5`** (default) | flagship coding/agentic | `low`, `medium`, `high` (default `high`) | ❌ always reasons |

**`--reasoning-effort` (alias `--effort`)** accepts `low | medium | high` in 0.2.118; other values fail locally. Use low for latency-sensitive work and high for harder reasoning. The JSON `thought` field is not a full reasoning trace and should not be used to estimate the effort applied.

> The wider xAI **API** (raw `api.x.ai` with an API key — `grok-4.3`, `grok-4.20-*`, `grok-3-mini`, etc., per [xAI docs](https://docs.x.ai/docs/models)) is a **separate surface** and is **not** selectable through `grok -m` on a grok.com login. A different account/plan may expose a different set — trust that account's `grok models` output, not this table.

## Vision (image input)

Image support is **per-model, not a CLI feature.** There is no `--image` flag — put the image file in the workspace (`--cwd`) and name it in the prompt; a multimodal model reads it. Grok's models are multimodal and see it; some text-only models (on other CLIs) can't. If you need vision, use a multimodal model.

## Setup / auth

- `grok` on PATH (`grok --version`); `grok login` / `grok logout` manage auth (here: logged in with grok.com). `grok inspect` shows the config Grok discovers for a directory.
- Long runs: `grok -p` is a full agentic loop — run it in the background or with a generous timeout so it isn't killed by a default tool timeout; cap turns with `--max-turns`.

Sources: [Grok Build overview](https://docs.x.ai/build/overview), [Headless & Scripting](https://docs.x.ai/build/cli/headless-scripting), [Permissions](https://docs.x.ai/build/features/permissions), and [Grok 4.5](https://docs.x.ai/developers/grok-4-5).
