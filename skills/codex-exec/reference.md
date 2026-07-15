# `codex exec` — full CLI reference

`codex exec` (alias `codex e`) runs the [Codex CLI](https://developers.openai.com/codex/cli) non-interactively: it takes a prompt, works the task autonomously, streams results to stdout (or JSONL), and exits. Docs: https://learn.chatgpt.com/docs/developer-commands?surface=cli#cli-codex-exec — always cross-check `codex exec --help` for the installed version; flags evolve.

## Mental model: Codex is itself an agent

`codex exec` is **not** a one-shot completion endpoint — it's a full agent (like Claude Code) that runs inside the workspace you point it at. Given `-C <dir>` it will, on its own:

- **read files and run `git`** (verified: `codex exec -s read-only -C <dir> "read notes.txt and print its first line"` → prints the correct line);
- use **`gh`** (GitHub CLI), ripgrep, and other shell tools within the sandbox;
- load the user's **`~/.codex` configuration** — MCP servers, plugins, skills (`~/.codex/skills`), and hooks all apply to `exec` runs.

**Consequence:** don't paste file contents into the prompt when the files are in the workspace — name the paths and let Codex read them. Only pipe content in (stdin) when it lives *outside* the workspace root (e.g. a diff against a remote, a log from elsewhere).

## Flags and options

| Flag | Type / Values | Details |
|------|---------------|---------|
| `--cd, -C` | path | Workspace root Codex operates in. **Must precede a subcommand** (e.g. `codex exec -C <dir> review …`) |
| `--color` | `always` \| `never` \| `auto` | ANSI color in stdout |
| `--dangerously-bypass-approvals-and-sandbox, --yolo` | boolean | Bypasses approvals **and** sandbox (**high risk**) |
| `--dangerously-bypass-hook-trust` | boolean | Runs enabled hooks without persisted trust |
| `--ephemeral` | boolean | Don't persist session files to disk |
| `--full-auto` | boolean | Deprecated; prefer `--sandbox workspace-write` |
| `--ignore-rules` | boolean | Skip user/project execpolicy `.rules` files |
| `--ignore-user-config` | boolean | Bypass `$CODEX_HOME/config.toml` (auth still uses CODEX_HOME) |
| `--image, -i` | path[,path...] | Attach image(s) to the initial message; repeatable |
| `--json, --experimental-json` | boolean | Newline-delimited JSON events instead of formatted text |
| `--local-provider` | `lmstudio` \| `ollama` | Local provider for `--oss` runs |
| `--model, -m` | string | Override the model for this run |
| `--oss` | boolean | Use a local open-source provider |
| `--output-last-message, -o` | path | Write **only** the assistant's final message to a file |
| `--output-schema` | path | Validate tool output against a JSON Schema file |
| `--profile, -p` | string | Layer `$CODEX_HOME/<name>.config.toml` on the base config |
| `--sandbox, -s` | `read-only` \| `workspace-write` \| `danger-full-access` | Sandbox policy for model-generated commands |
| `--add-dir` | path | Extra directory writable alongside the workspace root |
| `--skip-git-repo-check` | boolean | Allow running outside a Git repo |
| `--enable` / `--disable` | FEATURE | Toggle a feature for this run (= `-c features.<name>=true/false`); repeatable |
| `-c, --config` | key=value | Inline config override; repeatable; value parsed as TOML, dotted paths for nesting |
| `PROMPT` | string \| `-` (stdin) | Task instruction, or `-`/piped stdin. Prompt arg + piped stdin → stdin appended as a `<stdin>` block |

## Sandbox and approval modes (pick the least privilege that works)

- `read-only` (default) — read files, run `git`/`gh`, reason; **no writes**. Use for review, investigation, Q&A, and "auxiliary implement" (Codex proposes; you apply).
- `workspace-write` — may edit files **anywhere under the workspace root** (not just the file you named). Use only when the user wants Codex to edit directly.
- `danger-full-access` — no sandbox on shell commands. Avoid unless the environment is already externally sandboxed.
- `--yolo` / `--dangerously-bypass-approvals-and-sandbox` — skips approvals **and** sandbox. Extremely dangerous; confirm with the user first.

## Subcommands

### `codex exec review` — built-in code review (preferred for "review my PR")

```bash
codex exec -C <repo> review --uncommitted          # staged + unstaged + untracked (includes new files)
codex exec -C <repo> review --base main            # this branch vs a base branch (true PR diff)
codex exec -C <repo> review "focus on the auth changes and concurrency"   # custom instructions
```

- `-C` **must come before `review`** — `codex exec review -C <dir>` errors with `unexpected argument '-C'`.
- Codex runs `git status`/`git diff` itself and reads the changed files; `--uncommitted` picks up untracked files that a plain `git diff` misses.
- With `gh` available, Codex can also inspect a real GitHub PR (e.g. tell it "review PR #123" and it can fetch details via `gh`).

### `codex exec resume` — continue a session

```bash
codex exec resume <SESSION_ID> "follow-up instruction"
codex exec resume --last "address the review comments"   # most recent session
```

### Related top-level commands

- `codex apply` (alias `codex a`) — apply Codex's latest produced diff to your working tree via `git apply`. Useful after a read-only "auxiliary" run that returned a diff.
- `codex doctor` — diagnose install/config/**auth**/runtime health.

## Output modes and shape

- **Default (text):** chatty — a header block (`workdir`/`model`/`sandbox`/`session id`), the echoed prompt, `hook:` lines for any configured hooks, the answer, and a `tokens used` line. The final assistant message is at the **end** (and is printed twice: once inline, once as the final line).
- **`--json`:** newline-delimited JSON events — parse in scripts.
- **`-o <file>`:** writes only the assistant's final message to a file — the clean way to capture just the answer.

## Model and auth notes

- Auth is either a **ChatGPT account** (`codex login`) or `OPENAI_API_KEY`. Check with `codex doctor` (look for the `auth` line).
- On a **ChatGPT account, the model must be one Codex supports for that account.** An unsupported/unknown `-m` value prints `warning: Model metadata for '<id>' not found. Defaulting to fallback metadata …` and then fails the run with:
  `ERROR: {"type":"error","status":400,"error":{"type":"invalid_request_error","message":"The '<id>' model is not supported when using Codex with a ChatGPT account."}}`
  → surface this to the user and suggest a supported model; don't silently retry.
- With no `-m` and no `model=` in config, Codex uses its configured default model.

## Available models and reasoning effort

Select a model with `-m <slug>` and its reasoning effort with `-c model_reasoning_effort="<effort>"` (also settable in `~/.codex/config.toml`, or interactively via `/model`). Effort is per-model — a model only accepts the levels in its row.

**Scope:** this is the complete list Codex exposes for **this ChatGPT account** — a curated set of Codex coding models, **not** the full OpenAI API catalog. There is deliberately no GPT-4 family, no `nano`, no o-series, and no plain `gpt-5.3-codex` (only `-spark`); requesting one of those hits the `400 … "not supported when using Codex with a ChatGPT account"` error (see [Model and auth notes](#model-and-auth-notes)). API-key auth (`OPENAI_API_KEY`) may expose a different set.

The table below merges the model manifest (`~/.codex/models_cache.json`, client `0.144.3`, fetched 2026-07-14) with the **accepted-effort set verified empirically** (running each level and reading the CLI's error on rejection). The two don't perfectly agree: `none` is accepted by most models but is **not** listed in the manifest's picker levels, so trust the "Accepts `none`" column here over the manifest. Manifest is account/version-specific and auto-refreshes — re-verify after upgrades.

| Model slug | Display name | Accepted efforts (via `-c model_reasoning_effort`) | Accepts `none` (reasoning off)? | In API |
|------------|--------------|-----------------------------------------------------|:---:|:---:|
| `gpt-5.6-sol` | GPT-5.6-Sol — "latest frontier agentic coding model" (default model here) | none, low, medium, high, xhigh, max, ultra | ✅ | yes |
| `gpt-5.6-terra` | GPT-5.6-Terra | none, low, medium, high, xhigh, max, ultra | ✅ | yes |
| `gpt-5.6-luna` | GPT-5.6-Luna | none, low, medium, high, xhigh, max | ✅ | yes |
| `gpt-5.5` | GPT-5.5 | none, low, medium, high, xhigh | ✅ | yes |
| `gpt-5.4` | GPT-5.4 | none, low, medium, high, xhigh | ✅ | yes |
| `gpt-5.4-mini` | GPT-5.4-Mini | none, low, medium, high, xhigh | ✅ | yes |
| `gpt-5.3-codex-spark` | GPT-5.3-Codex-Spark | low, medium, high, xhigh | ❌ **requires reasoning** | no |
| `codex-auto-review` | Codex Auto Review (hidden — internal, drives `review`) | low, medium, high, xhigh *(manifest; not user-invoked)* | — (untested) | yes |

**Reasoning-effort ladder** (lowest → highest; higher = deeper reasoning, slower, more tokens):

| Effort | Meaning |
|--------|---------|
| `none` | **Reasoning off** — fastest, cheapest, no thinking tokens. **The default for `codex exec`** (see below). |
| `low` | Fast responses with lighter reasoning |
| `medium` | Balances speed and reasoning depth for everyday tasks |
| `high` | Greater reasoning depth for complex problems |
| `xhigh` | Extra-high reasoning depth for complex problems |
| `max` | Maximum reasoning depth for the hardest problems (`sol`/`terra`/`luna` only) |
| `ultra` | Maximum reasoning **with automatic task delegation** (`sol`/`terra` only) |

`minimal` is **not** a valid level for any of these models — passing it errors (`Unsupported value: 'minimal' …`). It exists on some older/other Codex models but not this account's set.

### Turning reasoning off (`none`)

- **`codex exec` already defaults to `none`** (verified: the run header prints `reasoning effort: none` with no flag). So a plain `codex exec -m <model> "…"` runs with reasoning **off** — fast and cheap. Set it explicitly with `-c model_reasoning_effort="none"` when you want to be sure (or override an inherited config default).
- **Exception — `gpt-5.3-codex-spark` cannot run with reasoning off.** It rejects `none` (`Unsupported value: 'none' is not supported … Supported values are: 'low', 'medium', 'high', and 'xhigh'`). Because `exec`'s default *is* `none`, spark **fails even with no effort flag** — you must pass `-c model_reasoning_effort="low"` (or higher):
  ```bash
  codex exec -m gpt-5.3-codex-spark -c model_reasoning_effort="low" -s read-only -C <repo> "…"
  ```
- **When to raise it:** bump to `high`/`xhigh` (or `max`/`ultra` on `sol`/`terra`) for genuinely hard reasoning; leave at `none`/`low` for quick lookups, mechanical edits, and reviews where speed matters.

```bash
# reasoning OFF (also the default) — fast
codex exec -m gpt-5.6-sol -c model_reasoning_effort="none" -s read-only -C <repo> "…"
# hardest tasks on the frontier model
codex exec -m gpt-5.6-sol -c model_reasoning_effort="max" -s read-only -C <repo> "…"
```

## Codex's own capabilities in an `exec` run

`exec` inherits the user's `~/.codex` setup: **MCP servers** (e.g. context7, playwright, ai-memory, …), **plugins** (e.g. github, figma), **skills** (`~/.codex/skills` — same set as `~/.claude/skills` here), and **hooks**. Scope per run with `--enable <feature>` / `--disable <feature>` and `-c key=value`. Inspect with `codex features list`, `codex plugin list`, `codex mcp`.

## Prompt input

- Argument: `codex exec "…"`.
- Stdin (for content outside the workspace): `git diff origin/main | codex exec -s read-only "review this diff"`, or `codex exec - < prompt.txt`. Prompt arg **and** piped stdin → stdin is appended as a `<stdin>` block.

## Config overrides

```bash
codex exec -c model="o3" -c 'sandbox_permissions=["disk-full-read-access"]' "…"
```

## Setup / auth

- `codex` must be on PATH (`codex --version`).
- Auth is interactive: the user runs `codex login` themselves.
- By default Codex requires a Git repo; pass `--skip-git-repo-check` to run outside one.
