# `codex exec` — full CLI reference

`codex exec` (alias `codex e`) runs the [Codex CLI](https://developers.openai.com/codex/cli) non-interactively: it takes a prompt, works autonomously, streams progress to stderr, prints the final message to stdout (or emits JSONL), and exits. Verified against `codex-cli 0.145.0` on 2026-08-04; `codex doctor` reported 0.146.0 available but it was not installed during this audit. Always cross-check `codex exec --help`, `codex debug models`, and the [official CLI reference](https://learn.chatgpt.com/docs/developer-commands?surface=cli#cli-codex-exec).

## Mental model: Codex is itself an agent

`codex exec` is **not** a one-shot completion endpoint — it's a full agent (like Claude Code) that runs inside the workspace you point it at. Given `-C <dir>` it will, on its own:

- **read files and run `git`** (verified: `codex exec -s read-only -C <dir> "read notes.txt and print its first line"` → prints the correct line);
- use `git`, ripgrep, and other shell tools within the sandbox; remote tools such as `gh` additionally need command-network access and authentication;
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

- `read-only` (default) — read local files, run local Git inspection, reason; **no writes and no command networking by default**. Use for review, investigation, Q&A, and "auxiliary implement".
- `workspace-write` — may edit ordinary files across the workspace root (not just the file named). `.git`, `.agents`, and `.codex` are protected by default; command networking is configured separately.
- `danger-full-access` — no sandbox on shell commands. Avoid unless the environment is already externally sandboxed.
- `--yolo` / `--dangerously-bypass-approvals-and-sandbox` — skips approvals **and** sandbox. Extremely dangerous; confirm with the user first.

## Subcommands

### `codex exec review` — built-in code review (preferred for "review my PR")

```bash
codex exec -C <repo> -c 'sandbox_mode="read-only"' review --uncommitted
codex exec -C <repo> -c 'sandbox_mode="read-only"' review --base main
codex exec -C <repo> -c 'sandbox_mode="read-only"' review --commit <SHA> --title "change title"
codex exec -C <repo> -c 'sandbox_mode="read-only"' review "focus on auth and concurrency"
```

- `-C` **must come before `review`** — `codex exec review -C <dir>` errors with `unexpected argument '-C'`.
- Review runs can inherit a permissive sandbox from user/config context; use the explicit override above and verify the startup header says `sandbox: read-only`.
- `--uncommitted`, `--base`, `--commit`, and a custom prompt are mutually exclusive; `--title` requires `--commit`.
- Codex runs `git status`/`git diff` itself and reads the changed files; `--uncommitted` picks up untracked files that a plain `git diff` misses.
- Remote PR fetching is not a built-in review target and is conditional on separately enabled command networking plus authenticated tooling.

### `codex exec resume` — continue a session

```bash
codex exec resume <SESSION_ID> "follow-up instruction"
codex exec resume --last "address the review comments"   # most recent session
codex exec resume --last --all "continue across cwd boundaries"
```

`SESSION_ID` may be a UUID or thread name. `--last` is current-working-directory-filtered unless `--all` is supplied.

### Related top-level commands

- `codex apply <TASK_ID>` (alias `codex a`) — apply the latest diff from a **Codex cloud task**. It does not apply the last local exec diff.
- `codex doctor` — diagnose install, updates, config, auth, and runtime health.

## Output modes and shape

- **Default:** final message on stdout; progress, header, tools, inline answer, and token accounting on stderr. A terminal that merges streams can make the answer appear twice.
- **`--json`:** newline-delimited JSON events — parse in scripts.
- **`-o <file>`:** writes only the assistant's final message to a file — the clean way to capture just the answer.

## Model and auth notes

- Auth is either a **ChatGPT account** (`codex login`) or `OPENAI_API_KEY`. Check with `codex login status` or `codex doctor`.
- On a **ChatGPT account, the model must be one Codex supports for that account.** An unsupported/unknown `-m` value prints `warning: Model metadata for '<id>' not found. Defaulting to fallback metadata …` and then fails the run with:
  `ERROR: {"type":"error","status":400,"error":{"type":"invalid_request_error","message":"The '<id>' model is not supported when using Codex with a ChatGPT account."}}`
  → surface this to the user and suggest a supported model; don't silently retry.
- With no `-m` and no `model=` in config, Codex uses its configured default model.

## Available models and reasoning effort

Select a model with `-m <slug>` and its reasoning effort with `-c model_reasoning_effort="<effort>"` (also settable in `~/.codex/config.toml`, or interactively via `/model`). Effort is per-model — a model only accepts the levels in its row.

**Scope:** this is the dated account-visible catalog for the audited ChatGPT login, not the complete OpenAI API catalog. Refresh with `codex debug models`; auth mode, plan, policy, rollout, and client version can change it.

| Model slug | Catalog default | Catalog-advertised efforts | Explicit `none` observation | Catalog API field |
|------------|-----------------|----------------------------|-----------------------------|:---:|
| `gpt-5.6-sol` | low | low, medium, high, xhigh, max, ultra | worked on this account | yes |
| `gpt-5.6-terra` | medium | low, medium, high, xhigh, max, ultra | untested | yes |
| `gpt-5.6-luna` | medium | low, medium, high, xhigh, max | untested | yes |
| `gpt-5.5` | medium | low, medium, high, xhigh | untested | yes |
| `gpt-5.4` | medium | low, medium, high, xhigh | untested | yes |
| `gpt-5.4-mini` | medium | low, medium, high, xhigh | untested | yes |
| `gpt-5.3-codex-spark` | high | low, medium, high, xhigh | explicit `none` rejected; unset worked | no |
| `codex-auto-review` | medium | low, medium, high, xhigh, max | hidden/internal; untested | yes |

The generic public alias `gpt-5.6` failed on this ChatGPT-account CLI even though the exact family slugs worked. Prefer a live catalog slug. OpenAI has also announced that GPT-5.4 and GPT-5.4-mini retire from Codex with ChatGPT sign-in on 2026-08-31.

### Unset effort versus explicit `none`

- Omitting `model_reasoning_effort` uses user configuration and/or model defaults. The audited user config selected `high`; do not call omission “reasoning off.”
- With user config ignored, the header printed `reasoning effort: none`; Spark still ran and its catalog default is `high`. That label can mean no override, not proof of disabled reasoning.
- Explicit `-c model_reasoning_effort="none"` succeeded on Sol and failed on Spark. Pass `low` or higher when you need an explicit portable Spark tier.
- `minimal` was rejected by the tested Sol configuration. Treat accepted levels as model/account-specific.

```bash
# explicit reasoning off where supported
codex exec -m gpt-5.6-sol -c model_reasoning_effort="none" -s read-only -C <repo> "…"
# hardest single-model reasoning tier on Sol
codex exec -m gpt-5.6-sol -c model_reasoning_effort="max" -s read-only -C <repo> "…"
```

## Codex's own capabilities in an `exec` run

`exec` inherits the user's `~/.codex` setup: **MCP servers** (e.g. context7, playwright, ai-memory, …), **plugins** (e.g. github, figma), **skills** (`~/.codex/skills` — same set as `~/.claude/skills` here), and **hooks**. Scope per run with `--enable <feature>` / `--disable <feature>` and `-c key=value`. Inspect with `codex features list`, `codex plugin list`, `codex mcp`.

## Prompt input

- Argument: `codex exec "…"`.
- Stdin (for content outside the workspace): `git diff origin/main | codex exec -s read-only "review this diff"`, or `codex exec - < prompt.txt`. Prompt arg **and** piped stdin → stdin is appended as a `<stdin>` block.

## Config overrides

```bash
codex exec -c 'model="gpt-5.6-sol"' -c 'model_reasoning_effort="low"' -s read-only "…"
```

## Setup / auth

- `codex` must be on PATH (`codex --version`).
- Auth is interactive: the user runs `codex login` themselves.
- By default Codex requires a Git repo; pass `--skip-git-repo-check` to run outside one.
