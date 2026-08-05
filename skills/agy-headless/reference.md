# `agy -p` (Antigravity CLI, headless / print) — full reference

`agy -p <PROMPT>` (aliases `--print` / `--prompt`) runs Google's **Antigravity CLI** non-interactively: it runs a single prompt as a full agent and prints the response, then exits. It's the headless entry point — the Antigravity analog of `claude -p` / `codex exec` / `grok -p`. Verified against `agy 1.1.10` on 2026-08-04; re-check `agy --help`, `agy models`, and `agy changelog` because this CLI is moving quickly.

## Mental model

`agy` is a **multi-vendor aggregator** (one Google/Antigravity login → Gemini **and** Claude **and** GPT-OSS models) and a **full agent**, not a completion. Three things that bite, all different from the other headless CLIs:

- **No print-mode cwd/`-C`/`--cwd`.** `agy -p` uses a scratch fallback (`~/.gemini/antigravity-cli/scratch/`) rather than exposing the launch directory as a workspace. To give it your repo you MUST pass **`--add-dir <path>`** (repeatable). A live read without it reported no active workspace; the same read with `--add-dir` succeeded.
- **Models use stable slugs and effort is separate.** Prefer a base family slug plus `--effort`; `agy models` currently prints effort-suffixed selections, which also work when no conflicting effort is supplied.
- **Structured output is available, but tool denial is not a JSON error.** `--output-format` accepts `text`, `json`, and `stream-json`. A denied tool can still end with `status:"SUCCESS"` and an empty response, so capture stderr and verify side effects.

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
| **default** (no flag) | Tools that would prompt are soft-denied in headless mode; a notice is printed to stderr. |
| `--mode accept-edits` | Selects accept-edits mode, but on 1.1.10 a headless `write_file` probe was still soft-denied. |
| `--mode plan` | Plan only — no changes |
| `--dangerously-skip-permissions` | Auto-approve **all** tool permission requests (files + commands) — only in a trusted/sandboxed dir; confirm with the user first |
| `--sandbox` | Run with terminal restrictions enabled |

**Rule:** prefer a narrow allow-rule under `permissions.allow` in `settings.json`, such as `write_file(<target>)`, plus `--add-dir`. Reserve the dangerous bypass for explicit authorization. A bounded `--print-timeout` still protects against unrelated stalls.

## Key flags

| Flag | Details |
|------|---------|
| `-p` / `--print` / `--prompt <P>` | Run a single prompt non-interactively and print the response |
| `--add-dir <DIR>` | Add a directory to the workspace (**repeatable**) — how `agy` gets your files |
| `--model <SLUG>` | Model for the session — preferably a base family slug with `--effort`, or an exact effort-suffixed value emitted by `agy models` |
| `--effort <E>` | Reasoning effort for the selected model: `low` \| `medium` \| `high` |
| `--mode <M>` | Execution mode: `accept-edits` \| `plan` |
| `--dangerously-skip-permissions` | Auto-approve all tool permission requests |
| `--sandbox` | Run in a sandbox with terminal restrictions |
| `--agent <NAME>` | Agent for this session (`agy agents` lists them) |
| `--print-timeout <DUR>` | Timeout for print-mode wait (**default `5m0s`**) — bump for long agentic runs, lower to fail fast on a hang |
| `--output-format <F>` | `text` (default) \| `json` \| `stream-json` |
| `--json-schema <JSON-or-path>` | Constrain structured final output; in `stream-json`, applies to the final result |
| `--disable-slash-commands` | Disable slash-command and skill expansion in print mode |
| `-c` / `--continue` | Continue the most recent conversation |
| `--conversation <ID>` | Resume a previous conversation by ID |
| `-i` / `--prompt-interactive <P>` | Run an initial prompt, then stay interactive (not headless) |
| `--project <ID>` / `--new-project` | Scope to / create an Antigravity project |
| `--log-file <PATH>` | Override the CLI log path |

Subcommands: `agy models` (list models), `agy agents` (list agents), `agy plugin`, `agy update`, `agy install` (shell/env setup).

## Output

- `text`: final response text.
- `json`: one object with `conversation_id`, `status`, `response`, `duration_seconds`, `num_turns`, and `usage`.
- `stream-json`: typed NDJSON progress plus a final result.

There is no structured permission-denial field in the observed JSON. On 1.1.10, a blocked write printed a stderr `write_file` denial, then returned `{"status":"SUCCESS","response":""}`. Treat process output, stderr, and `git diff`/filesystem state together.

## Models and effort

`agy models` is the account-specific source of truth. Gemini families accept a base slug with effort supplied separately; vendor models that expose only a fixed emitted slug should use that exact slug without a conflicting effort:

| Model slug (`--model` value) | Effort handling | Vendor |
|-----------------------------------|-----------------|--------|
| `gemini-3.6-flash`, `gemini-3.5-flash`, `gemini-3.1-pro` | add `--effort`; or use an emitted suffixed selection | Google |
| `claude-sonnet-4-6`, `claude-opus-4-6-thinking` | fixed emitted slug; omit a conflicting `--effort` | Anthropic |
| `gpt-oss-120b-medium` | fixed emitted slug; omit a conflicting `--effort` | open-weight |

- **Selection:** for Gemini, prefer a base family slug such as `gemini-3.6-flash` with `--effort low`; or pass an emitted selection such as `gemini-3.6-flash-low` without a conflicting effort. For Claude/GPT-OSS entries with no base variant, use the exact emitted slug. Unknown values fail instead of silently falling back (fixed in 1.1.2).
- **Effort:** use `--effort low|medium|high`. Version 1.1.10 fixed earlier cases where `--model`/`--effort` were silently ignored in print mode, so do not generalize results from older releases.
- The lineup drifts (Antigravity is new and Google-managed) — re-run `agy models` rather than trusting this table.

## Vision (image input)

Image support is **per-model, not a CLI feature** — and it matters most here because `agy` is multi-vendor. There is no `--image` flag: put the image under `--add-dir` and name it in the prompt; a multimodal model reads it. Some text-only models can't see images, so pick a multimodal model when the task needs vision.

## Setup / auth

- `agy` on PATH (`agy --version`); logs in with a Google/Antigravity account. `agy install` configures shell/env; `agy update` upgrades.
- Antigravity is the **successor to Gemini CLI** (which is being sunset for free/consumer users) — this is Google's current headless coding agent.
