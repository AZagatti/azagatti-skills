# `claude -p` (headless / print mode) — full reference

`claude -p` (`--print`) runs Claude Code in **non-interactive mode** (formerly headless): it takes a prompt, runs a full agentic session, prints the result, and exits. Verified against `claude 2.1.220` on 2026-08-04; re-check `claude --help` and the [official CLI reference](https://code.claude.com/docs/en/cli-usage).

## Mental model

Like `codex exec`, `claude -p` is a **full agent**, not a completion — it reads files, runs `git`/shell, uses MCP servers and skills, in whatever directory it's launched from. It is a **separate Claude Code session**: its own context, its own cost, its own session id. It inherits your auth and (unless `--bare`/`--safe-mode`) your `CLAUDE.md`, hooks, skills, and MCP config.

Two things that bite people:

- **No `-C`/workspace flag — the working directory *is* the launch cwd.** Point it at a repo by launching there: `(cd <repo> && claude -p "…")`. Use `--add-dir <path>` to grant read/tool access to extra directories.
- **Headless permissions inherit configuration** (see below) — a tool that would prompt interactively is **denied** in `-p` mode, and the run still exits `is_error: false`, but configured default modes and allow rules may pre-authorize more. Always choose a fail-closed mode for automation and check `permission_denials`.

## Permission model (the most-forgotten part)

In `-p` mode there's no human to approve tool calls, so:

| Mode (flag) | Read/Grep/Glob | Edit/Write | Bash / mutating |
|-------------|:---:|:---:|:---:|
| **configured baseline** (no flag) | usually run; can be changed by config | depends on default mode/rules | prompt-class calls deny unless pre-authorized |
| `--permission-mode acceptEdits` | ✅ | ✅ | common in-scope filesystem commands auto-approved; other Bash gated |
| `--permission-mode plan` | ✅ (plans only, no changes) | ❌ | ❌ |
| `--permission-mode bypassPermissions` | ✅ | ✅ | ✅ (everything) |
| `--dangerously-skip-permissions` | ✅ | ✅ | ✅ (everything) |
| `--allowedTools "Edit Bash(git *)"` | ✅ | granular allow-list | granular |

Observed on the audited configuration: with no permission flag, a **Read** task returned the file's content; a **Write** task returned `permission_denials: ["Write"]`, `is_error: false`, and did not create the file even though `.result` claimed success. With `--permission-mode acceptEdits` the same write succeeded. This is an account/config observation, not a universal default contract.

**Rule:** pick the least privilege that lets the task complete, and when the task should change files, use `--output-format json` and assert `permission_denials` is empty (don't trust `.result` prose or the exit code alone).

For a locked-down built-in read surface, prefer `--permission-mode dontAsk --tools "Read,Grep,Glob"`; add only narrowly scoped read-only Bash permissions when required. Inherited MCP servers, hooks, and managed policy still apply; add `--safe-mode` and explicit MCP configuration when stronger isolation is required. Omitting the flag inherits the user's configured baseline.

`acceptEdits` also auto-approves common filesystem commands such as `mkdir`, `touch`, `rm`, `rmdir`, `mv`, `cp`, and `sed` when they target the working directory or an added directory. Other Bash commands and protected/out-of-scope paths remain gated.

- `--dangerously-skip-permissions` / `--allow-dangerously-skip-permissions` — full bypass (incl. network-capable Bash). Only in a trusted/sandboxed dir; confirm with the user first. `-p` also auto-skips the workspace-trust dialog, so only run it in directories you trust.
- `--tools "Read,Grep,Glob"` restricts the *available* built-in tool set (use `""` to disable all, `"default"` for all); `--allowedTools`/`--disallowedTools` gate *permission* to use them.

## Key flags

| Flag | Details |
|------|---------|
| `-p, --print` | Non-interactive: print result and exit |
| `--output-format` | `text` (default, clean answer) · `json` (single result object) · `stream-json` (realtime events) — only with `-p` |
| `--input-format` | `text` (default) · `stream-json` (realtime streaming input) |
| `--model` | Alias (`default`, `best`, `fable`, `opus`, `sonnet`, `haiku`, `opusplan`) or full id. Omission follows Claude Code account/config/organization precedence. |
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
  - `structured_output` — parsed object produced by `--json-schema`; `result` remains a serialized string
- **`stream-json`**: newline-delimited events as they happen (add `--include-partial-messages` for token-level, `--include-hook-events` for hooks).

Capture just the answer: `claude -p "…" --output-format json | jq -r .result`.

## Models and effort

Aliases resolve dynamically by provider, account, organization policy, and CLI version. On the audited first-party Max account, omission and `opus` resolved to Opus 5, `sonnet` to Sonnet 5, `haiku` to Haiku 4.5, and `fable` to Fable 5. Use a full id when reproducibility matters; still expect organization allowlists to apply.

**`--effort` accepts `low | medium | high | xhigh | max`, but support is per-model.** For an effort-capable model, Claude Code falls back to the highest supported level at or below the request; organization policy may clamp it further. The live CLI accepted `--model haiku --effort high`, but its JSON does not expose an applied effort, so that only proves argument acceptance—not that effort affected Haiku.

| Model family | Documented `--effort` levels |
|--------------|------------------------------|
| Fable 5, Opus 5, Sonnet 5, Opus 4.8, Opus 4.7 | low, medium, high, xhigh, max |
| Opus 4.6, Sonnet 4.6 | low, medium, high, max |
| Models not listed, including Haiku 4.5 | no documented effort support |

Claude Code also documents `ultracode` as a separate orchestration setting, not a raw model effort tier. Use the [official model configuration](https://code.claude.com/docs/en/model-config) as the live source.

**Delegation tip:** to offload cheap/parallel work, run `--model haiku` (no effort — it's already fast) or `--model sonnet --effort low` in a `claude -p` subprocess while your main (Opus) session orchestrates.

## Cost and isolation notes

A fresh `claude -p` run loads project customizations and can create substantial cache input. Inspect `total_cost_usd` and every `modelUsage` entry; cap spend with `--max-budget-usd`.

- `--bare`: skips hooks, LSP, plugin sync, auto-memory, keychain reads, and CLAUDE.md auto-discovery. Built-in tools and explicit skills still exist. First-party auth must come from `ANTHROPIC_API_KEY` or `apiKeyHelper`; subscription OAuth is not read.
- `--safe-mode`: disables customizations but keeps normal auth, built-in tools, model selection, and permissions.
- `--bg`: creates a supervised session managed with `claude agents`, `attach`, `logs`, and `stop`. Keep a foreground `-p` subprocess attached when a script expects one terminal JSON result.
- `-p --worktree`: creates a real Git worktree that is not automatically cleaned up after the non-interactive run; it is file isolation, not a security sandbox.
- `--resume <session_id>`: requires session persistence and the same project/repository scope. `-p` sessions are resumable by ID but hidden from the interactive picker; re-pass per-run flags such as `--add-dir` and `--mcp-config`.

## Setup / auth

- `claude` on PATH (`claude --version`); health via `claude doctor`.
- Inherits your existing Claude Code auth. `--bare` forces `ANTHROPIC_API_KEY`/apiKeyHelper only (no OAuth/keychain).
- `-p` skips the workspace-trust dialog and silently ignores invalid settings files — only run in trusted directories.
