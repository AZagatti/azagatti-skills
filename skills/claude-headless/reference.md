# `claude -p` (headless / print mode) — full reference

`claude -p` (`--print`) runs Claude Code **non-interactively**: it takes a prompt, runs a full agentic session (tools, MCP, skills), prints the result, and exits. It's the CLI/SDK/scripting entry point. Verified against `claude 2.1.208`; re-check `claude --help` for your version.

## Mental model

Like `codex exec`, `claude -p` is a **full agent**, not a completion — it reads files, runs `git`/shell, uses MCP servers and skills, in whatever directory it's launched from. It is a **separate Claude Code session**: its own context, its own cost, its own session id. It inherits your auth and (unless `--bare`/`--safe-mode`) your `CLAUDE.md`, hooks, skills, and MCP config.

Two things that bite people:

- **No `-C`/workspace flag — the working directory *is* the launch cwd.** Point it at a repo by launching there: `(cd <repo> && claude -p "…")`. Use `--add-dir <path>` to grant read/tool access to extra directories.
- **Headless permissions are restrictive by default** (see below) — a tool that would prompt interactively is **denied** in `-p` mode, and the run still exits `is_error: false`. So a "write the file" task can *report success while writing nothing*. Always check `permission_denials`.

## Permission model (the most-forgotten part)

In `-p` mode there's no human to approve tool calls, so:

| Mode (flag) | Read/Grep/Glob | Edit/Write | Bash / mutating |
|-------------|:---:|:---:|:---:|
| **default** (no flag) | ✅ run | ❌ **denied** | ❌ prompt-class denied |
| `--permission-mode acceptEdits` | ✅ | ✅ | still gated |
| `--permission-mode plan` | ✅ (plans only, no changes) | ❌ | ❌ |
| `--permission-mode bypassPermissions` | ✅ | ✅ | ✅ (everything) |
| `--dangerously-skip-permissions` | ✅ | ✅ | ✅ (everything) |
| `--allowedTools "Edit Bash(git *)"` | ✅ | granular allow-list | granular |

Verified: under default perms a **Read** task returns the file's content (no denial); a **Write** task returns `permission_denials: ["Write"]`, `is_error: false`, and **the file is not created** — even though `.result` says "Created …". With `--permission-mode acceptEdits` the same write succeeds.

**Rule:** pick the least privilege that lets the task complete, and when the task should change files, use `--output-format json` and assert `permission_denials` is empty (don't trust `.result` prose or the exit code alone).

- `--dangerously-skip-permissions` / `--allow-dangerously-skip-permissions` — full bypass (incl. network-capable Bash). Only in a trusted/sandboxed dir; confirm with the user first. `-p` also auto-skips the workspace-trust dialog, so only run it in directories you trust.
- `--tools "Read,Grep,Glob"` restricts the *available* built-in tool set (use `""` to disable all, `"default"` for all); `--allowedTools`/`--disallowedTools` gate *permission* to use them.

## Key flags

| Flag | Details |
|------|---------|
| `-p, --print` | Non-interactive: print result and exit |
| `--output-format` | `text` (default, clean answer) · `json` (single result object) · `stream-json` (realtime events) — only with `-p` |
| `--input-format` | `text` (default) · `stream-json` (realtime streaming input) |
| `--model` | Alias (`opus`, `sonnet`, `haiku`, `fable`) or full id (`claude-sonnet-5`, …). Default: inherits the parent/config model |
| `--effort` | Reasoning effort: `low` · `medium` · `high` · `xhigh` · `max` |
| `--permission-mode` | `acceptEdits` · `auto` · `bypassPermissions` · `manual` · `dontAsk` · `plan` |
| `--allowedTools`, `--disallowedTools` | Comma/space list, e.g. `"Bash(git *) Edit"` |
| `--tools` | Restrict the available built-in tool set (`""`=none, `"default"`=all, or `"Bash,Edit,Read"`) |
| `--dangerously-skip-permissions` | Bypass all permission checks |
| `--add-dir <dirs...>` | Extra directories tools may access |
| `--append-system-prompt <p>` | Append to the default system prompt |
| `--system-prompt <p>` | Replace the system prompt entirely |
| `--mcp-config <files...>` / `--strict-mcp-config` | Load MCP servers from JSON (and ignore all others) |
| `--agents <json>` / `--agent <name>` | Define/select custom subagents for the run |
| `--json-schema <schema>` | Validate structured output against a JSON Schema |
| `--max-budget-usd <amt>` | Hard cost cap for the run (only with `-p`) |
| `--fallback-model <m,…>` | Fall back when the primary is overloaded (only with `-p`) |
| `-r, --resume [id]` / `-c, --continue` | Resume a session by id / most recent in cwd |
| `--session-id <uuid>` / `--fork-session` / `--no-session-persistence` | Fix the id / branch on resume / don't save to disk |
| `--bare` | Minimal mode: skip hooks, LSP, plugin sync, auto-memory, **CLAUDE.md auto-discovery**. Cheaper/faster isolated runs; auth becomes API-key/apiKeyHelper only. Provide context explicitly via `--system-prompt`/`--add-dir`/`--mcp-config` |
| `--safe-mode` | Disable all customizations (troubleshooting) |
| `--bg, --background` | Start as a background agent, return immediately (manage via `claude agents`) |
| `-w, --worktree [name]` | Run in a fresh git worktree |
| `--verbose` / `-d, --debug [filter]` | Verbose / debug output |
| `PROMPT` | Positional arg, or pipe via stdin: `echo "…" \| claude -p` / `claude -p < file` |

> Note: this version has **no `--max-turns`**; bound cost with `--max-budget-usd` instead.

## Output shape

- **`text`** (default): just the final answer on stdout — clean, no header (unlike `codex exec`). Best for piping a single answer.
- **`json`**: one object. Useful fields:
  - `result` — the final assistant message (the answer)
  - `is_error` — **false even when tools were permission-denied** (see permission model)
  - `permission_denials[]` — `{tool_name, …}` for every denied tool call — **check this**
  - `total_cost_usd`, `usage`, `modelUsage` — cost/token accounting
  - `session_id` — pass to `--resume` to continue
  - `num_turns`, `duration_ms`, `stop_reason`, `subtype`
- **`stream-json`**: newline-delimited events as they happen (add `--include-partial-messages` for token-level, `--include-hook-events` for hooks).

Capture just the answer: `claude -p "…" --output-format json | jq -r .result`.

## Models and effort

**Aliases** → latest of each family: `opus` (`claude-opus-4-8`), `sonnet` (`claude-sonnet-5`), `haiku` (`claude-haiku-4-5`), `fable` (`claude-fable-5`). Pass a full id for a pinned/older version (e.g. `claude-opus-4-7`); `[1m]` suffix = 1M-context beta. With no `--model`, `-p` inherits the parent/config model (here `claude-opus-4-8[1m]`).

**`--effort` accepts `low | medium | high | xhigh | max`, but support is per-model — and not every model accepts every level.** Crucially, the **Claude Code CLI does not error on an unsupported model+effort combo** — it silently ignores the flag and runs anyway (verified: `--model haiku --effort high` → `is_error:false`, runs at Haiku's fixed behavior). So passing an effort a model doesn't support is harmless but does nothing. (This differs from the raw Anthropic API, which returns a 400 for the same combo.)

| Model (alias / id) | `--effort` levels that take effect | Reasoning off? |
|--------------------|-----------------------------------|:---:|
| `fable` → `claude-fable-5` | low, medium, high, xhigh, max | ❌ **thinking always on** (can't disable) |
| `opus` → `claude-opus-4-8` | low, medium, high, xhigh, max | ✅ (off unless thinking enabled) |
| `claude-opus-4-7` | low, medium, high, xhigh, max | ✅ |
| `claude-opus-4-6` | low, medium, high, max (**no `xhigh`**) | ✅ |
| `claude-opus-4-5` | low, medium, high (**no `xhigh`/`max`**) | ✅ |
| `sonnet` → `claude-sonnet-5` | low, medium, high, xhigh, max | ✅ |
| `claude-sonnet-4-6` | low, medium, high, max (**no `xhigh`**) | ✅ |
| `claude-sonnet-4-5` | **none — no effort support** | ✅ (thinking via budget, not effort) |
| `haiku` → `claude-haiku-4-5` | **none — no effort support** | ✅ |

`xhigh` arrived with Opus 4.7; `max` requires Opus 4.6+/Sonnet 4.6+/Sonnet 5/Fable 5. Source: the `claude-api` skill's model catalog (authoritative, API-level) — re-check it when new models ship. Use `low` for cheap mechanical/bulk work, `xhigh`/`max` for the hardest reasoning.

**Delegation tip:** to offload cheap/parallel work, run `--model haiku` (no effort — it's already fast) or `--model sonnet --effort low` in a `claude -p` subprocess while your main (Opus) session orchestrates.

## Cost note

A fresh `claude -p` run loads project context (`CLAUDE.md`, etc.), so even a trivial prompt costs cache-creation tokens (~$0.05–0.09 observed here). For cheap, isolated, context-free runs use `--bare` (skips CLAUDE.md/hooks/auto-memory). Cap spend with `--max-budget-usd`.

## Setup / auth

- `claude` on PATH (`claude --version`); health via `claude doctor`.
- Inherits your existing Claude Code auth. `--bare` forces `ANTHROPIC_API_KEY`/apiKeyHelper only (no OAuth/keychain).
- `-p` skips the workspace-trust dialog and silently ignores invalid settings files — only run in trusted directories.
