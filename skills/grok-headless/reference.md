# `grok -p` (Grok Build CLI, headless / single-turn) — full reference

`grok -p <PROMPT>` (long form `--single <PROMPT>`) runs xAI's **Grok Build CLI** non-interactively: it takes a prompt, runs a full agentic turn (tools, MCP, subagents), prints the response to stdout, and exits. It's the headless/scripting entry point — the Grok analog of `claude -p` and `codex exec`. Verified against `grok 0.2.93`; re-check `grok --help` for your version.

## Mental model

Like `claude -p` and `codex exec`, `grok -p` is a **full agent**, not a completion — it reads files, runs shell/`git`, uses MCP servers, plugins, and subagents, as its own session (own `sessionId`, own cost). It's evidently modeled on Claude Code — the `--help` cross-references Claude flags (`--allow` ↔ `--allowedTools`, `--system-prompt-override` ↔ `--system-prompt`).

Three things that bite:

- **`-p`/`--single` takes the prompt as its *value*.** The prompt must immediately follow `-p`; put every other flag **before `-p`** or after the prompt string. `grok -p --effort low "hi"` fails with `a value is required for '--single'` (see Quoting/ordering below). This is the #1 gotcha and differs from `claude -p` (a boolean).
- **Headless denies file writes by default.** A write/edit tool comes back `stopReason: "Cancelled"` and nothing happens — even though `text` says "Creating X". Grant write access explicitly (see Permissions).
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

Headless has no human to approve tool calls, so file-mutating tools are blocked unless you grant access. Verified behavior on `0.2.93`:

| Flag | Read/Grep/Glob | Write/Edit | Bash / mutating |
|------|:---:|:---:|:---:|
| **default** (no flag) | ✅ runs | ❌ **`Cancelled`** | ❌ blocked |
| `--always-approve` | ✅ | ✅ | ✅ (auto-approves **all** tool calls) |
| `--permission-mode bypassPermissions` | ✅ | ✅ | ✅ |
| `--permission-mode acceptEdits` | ✅ | ❌ **still `Cancelled`** | ❌ | 
| `--permission-mode plan` | ✅ (plans only) | ❌ | ❌ |
| `--allow <RULE>` / `--deny <RULE>` | granular | granular | granular (Claude Code: `--allowedTools`/`--disallowedTools`) |

Verified: under default perms a **read** task returns the file contents; a **write** task returns `stopReason: "Cancelled"` with the file **not created**; `--always-approve` and `bypassPermissions` both let the write land; **`acceptEdits` does *not* approve writes in headless** (both create and edit stayed `Cancelled`) — unlike `claude -p`, so don't rely on it.

**Rule:** default perms allow file **reads** but **deny command execution** (`git`, shell, subagents) — a denied tool returns `Cancelled` and Grok exits right after its preamble (silent no-op). So default is only safe for tasks Grok finishes with plain reads (or where you paste the diff/content into the prompt). **Anything that runs `git diff`/shell — including a "review the changes" task — needs `--always-approve`** (or `bypassPermissions`, or a scoped `--allow`). Verified: `grok -p "review… run git diff…"` under default → `Cancelled`; with `--always-approve` → `EndTurn` + a real review. Then verify with JSON (below). `--always-approve`/`bypassPermissions` auto-approve everything including Bash — only in a trusted/sandboxed dir; confirm with the user first. Scope tools with `--tools <list>` (allow-list of built-ins), `--disallowed-tools <list>`, or `--disable-web-search`. `--sandbox <PROFILE>` (env `GROK_SANDBOX`) applies a filesystem/network sandbox profile.

## Key flags

| Flag | Details |
|------|---------|
| `-p, --single <PROMPT>` | Single-turn: print response and exit. **Prompt is the flag's value** (see ordering) |
| `--prompt-file <PATH>` / `--prompt-json <JSON>` | Single-turn prompt from a file / as JSON content blocks (avoids shell quoting) |
| `--output-format` | `plain` (default) · `json` (single object) · `streaming-json` |
| `-m, --model <MODEL>` | Model id (default `grok-4.5`). See Models below |
| `--reasoning-effort <E>` (alias `--effort`) | Reasoning effort for reasoning models — `low`/`medium`/`high` (verified on grok-4.5). Tolerant: accepted (and ignored) on non-reasoning models |
| `--permission-mode <M>` | `default` · `acceptEdits` · `auto` · `dontAsk` · `bypassPermissions` · `plan` |
| `--always-approve` | Auto-approve **all** tool executions (simplest way to let writes land) |
| `--allow <RULE>` / `--deny <RULE>` | Permission allow/deny rule (Claude Code: `--allowedTools`/`--disallowedTools`) |
| `--tools <LIST>` / `--disallowed-tools <LIST>` | Allow-list / remove built-in tools (comma-separated) |
| `--disable-web-search` | Turn off web search + web fetch |
| `--sandbox <PROFILE>` | Filesystem/network sandbox profile (env `GROK_SANDBOX`) |
| `--cwd <DIR>` | Working directory Grok operates in |
| `--json-schema <SCHEMA>` | Constrain output to a JSON Schema (implies `--output-format json`) |
| `--max-turns <N>` | Cap agent turns |
| `--best-of-n <N>` | **Headless only** — run the task N ways in parallel, pick the best |
| `--check` | **Headless only** — append a self-verification loop to the prompt |
| `--rules <RULES>` / `--system-prompt-override <P>` | Append rules to / replace the system prompt |
| `--agent <NAME>` / `--agents <JSON>` / `--no-subagents` | Select/define custom agents; disable subagents |
| `-c, --continue` / `-r, --resume [ID]` / `-s, --session-id <UUID>` / `--fork-session` | Continue most recent / resume by id / fix id / branch on resume |
| `--experimental-memory` / `--no-memory` | Enable / disable cross-session memory |
| `-w, --worktree [NAME]` / `--worktree-ref <REF>` | Run in a fresh git worktree |
| `--verbatim` | Send the prompt exactly as given (no augmentation) |
| `--debug` / `--debug-file <FILE>` | Debug logging |

Subcommands: `grok models` (list account models), `grok agent {stdio,headless,serve}` (lower-level SDK harness — not the simple print mode), `grok sessions`, `grok export`, `grok inspect` (show discovered config), `grok mcp`, `grok login`/`logout`.

## Output shape

- **`plain`** (default): the response text on stdout — clean, best for piping one answer.
- **`json`**: one object. Fields: `text` (the answer), `thought` (reasoning), `stopReason` (`EndTurn` = done; **`Cancelled` = a tool was denied** — the tell-tale for a blocked write), `sessionId` (pass to `--resume`), `requestId`.
- **`streaming-json`**: newline-delimited events.

Capture just the answer: `grok -p "…" --output-format json | jq -r .text`. When a task should change files, assert `stopReason == "EndTurn"` (not `Cancelled`) and `git diff` — don't trust the `text` prose.

## Models and effort

**`grok models` is the ONLY authoritative list — the CLI rejects anything else.** The Grok Build CLI exposes a **curated set for your account/plan**, *not* the full xAI API catalog. Passing an unlisted model hard-errors: `grok -m grok-4.3` → `Couldn't set model 'grok-4.3': Invalid params: "unknown model id". Run 'grok models' to see available models.` (verified). So always run `grok models` and pick from it; don't pass an id you saw in xAI's web docs.

This install (logged in with grok.com) exposes exactly **two** — with **different** effort support (all verified by running each level):

| Model (from `grok models`) | Role | `--effort` levels that work | Reasoning off (`none`)? |
|----------------------------|------|-----------------------------|:---:|
| **`grok-4.5`** (default) | flagship coding/agentic | API accepts `minimal`, `low`, `medium`, `high`, `xhigh`, `max` (default `high`) — but xAI docs list only `low`/`medium`/`high`, so `minimal`/`xhigh`/`max` may clamp to the nearest documented tier | ❌ **`none` rejected** — always reasons; floor is `minimal` |
| `grok-composer-2.5-fast` | fast composer/coding model | `none`, `minimal`, `low`, `medium`, `high` (and higher) | ✅ **`none` accepted** |

**`--reasoning-effort` (alias `--effort`)** — the CLI *parser* accepts `none | minimal | low | medium | high | xhigh | max` (plus model-menu ids); an out-of-set value fails locally (`unknown effort level 'X'. Use none, minimal, …`). But **whether a level works is per-model, decided server-side** — e.g. `grok-4.5 --effort none` → API error `This model does not support reasoning_effort value 'none'`. So `grok-4.5` cannot run with reasoning off (minimum `minimal`, which still emits a short thought); `grok-composer-2.5-fast` *can* (`none`). Use `minimal`/`low` for cheap/bulk work, `high`/`max` for hard reasoning.

The levels are **distinct budgets, not aliases** — but effort is a *ceiling/bias*, not a fixed amount: the model reasons only as much as the task needs, up to that ceiling. So on easy/moderate tasks `minimal`≈`low`≈`high` in observed output (verified: grok-4.5 solved an inclusion-exclusion problem correctly at every level with the same visible reasoning); the gap only appears on tasks hard enough that a lower tier under-thinks. (The headless JSON `thought` field is a short preview, not the full trace — don't use its length to gauge reasoning depth.)

> The wider xAI **API** (raw `api.x.ai` with an API key — `grok-4.3`, `grok-4.20-*`, `grok-3-mini`, etc., per [xAI docs](https://docs.x.ai/docs/models)) is a **separate surface** and is **not** selectable through `grok -m` on a grok.com login. A different account/plan may expose a different set — trust that account's `grok models` output, not this table.

## Vision (image input)

Image support is **per-model, not a CLI feature.** There is no `--image` flag — put the image file in the workspace (`--cwd`) and name it in the prompt; a multimodal model reads it. Grok's models are multimodal and see it; some text-only models (on other CLIs) can't. If you need vision, use a multimodal model.

## Setup / auth

- `grok` on PATH (`grok --version`); `grok login` / `grok logout` manage auth (here: logged in with grok.com). `grok inspect` shows the config Grok discovers for a directory.
- Long runs: `grok -p` is a full agentic loop — run it in the background or with a generous timeout so it isn't killed by a default tool timeout; cap turns with `--max-turns`.

Sources: [xAI Grok models](https://docs.x.ai/docs/models), [Grok versions/API strings](https://mungomash.com/ai/grok/versions/).
