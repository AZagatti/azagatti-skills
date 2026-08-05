---
name: agy-headless
description: "Drive Google's Antigravity CLI with `agy -p` (headless) — a separate multi-vendor agent (Gemini / Claude / GPT-OSS via one login) for a delegated task, cross-vendor second opinion, or cheaper model. Use when the user mentions agy or Antigravity (the Gemini CLI successor), or wants to delegate to Gemini/Antigravity; or invokes `/agy-headless [model=<slug>] [effort=<level>] [dir=<path>] <task>`."
---

# agy-headless — driving `agy -p` (Antigravity)

Run Google's **Antigravity CLI** non-interactively with `agy -p` to spawn a separate agent — a **multi-vendor aggregator** (one login → Gemini, Claude, and GPT-OSS models). The headless analog of `codex-exec` / `claude-headless` / `grok-headless`. This skill exists because `agy` has a different workspace, permission, and output model that can report success after a denied tool.

## Mental model (read this first)

`agy -p` is a **full agent**, not a completion, and picks from Gemini/Claude/GPT-OSS behind one Google login. Three gotchas, all unlike the other headless CLIs:

- **Print mode does not expose your launch directory as a workspace.** You MUST pass **`--add-dir <path>`** for repository file tasks. Without it, the agent sees its scratch fallback under `~/.gemini/antigravity-cli/scratch/`, not your repo.
- **Models use stable slugs and effort is a separate flag.** Prefer a base family slug plus `--effort` (for example `gemini-3.6-flash --effort low`), or use an effort-suffixed value emitted by `agy models` without a conflicting effort.
- **Headless supports `text`, `json`, and `stream-json`, but denial is soft.** A blocked tool can print a stderr warning and still return JSON `status:"SUCCESS"` with an empty response. Verify side effects independently.

## Quick reference

| Need | Where |
| ---- | ----- |
| **`--add-dir`** (the #1 gotcha) | [reference.md → files](reference.md#giving-it-your-files---add-dir-the-1-gotcha) |
| **Permissions** (headless soft-denial) | [reference.md → Permissions](reference.md#permissions) |
| All flags | [reference.md → Key flags](reference.md#key-flags) |
| Models + `--effort` | [reference.md → Models](reference.md#models-and-effort) |

## 1. Parse the invocation

Called with a free-form task, optionally prefixed by `key=value` options:

```
/agy-headless dir=. review the changes in src/
/agy-headless model=claude-opus-4-6-thinking explain why this test flakes
/agy-headless dir=../repo model=gemini-3.6-flash effort=low summarize the architecture
```

- **Options are only the *contiguous leading* tokens whose key is `model`, `effort`, `dir`, or `mode`.** Stop at the first non-matching token — the rest is the **task**, verbatim.
- `model=<slug>` → `--model <slug>`. Prefer a base family slug with `effort=`, or an exact effort-suffixed value from `agy models` without a conflicting `effort=`. No `model=` → omit (uses the account/config default).
- `effort=<low|medium|high>` → `--effort <level>`. The model must support that tier.
- `dir=<path>` → **`--add-dir <path>`** (repeatable). **Default `dir` to the repo you want it to work on — never omit it for a file task**, or the agent cannot see that repo.
- `mode=<accept-edits|plan>` → `--mode`.

## 2. Pre-flight

- Resolve the file/dir the task is about; that path is what you pass to `--add-dir`. If the task touches files and you have no dir, **ask** rather than firing a run against the scratch fallback.

## 3. Build the command

**Always:** `--add-dir <repo>` for any task about your files, `-p "<prompt>"` last, explicit permission authorization if it must act, and a bounded `--print-timeout`.

| Task | Command |
| ---- | ------- |
| read / analyze / review / question | `agy --add-dir <repo> [--model <slug>] [--effort <e>] --output-format json --print-timeout 3m -p "<task>"` |
| must edit files | pre-approve an exact absolute `write_file(<target>)` rule under `permissions.allow` in `~/.gemini/antigravity-cli/settings.json`, then run with `--add-dir` and remove the rule afterward |
| full autonomy (files + commands) in a trusted dir | add `--dangerously-skip-permissions` (confirm with user first) |

- **Without `--add-dir` the agent can't see your repository files** and may answer from the scratch fallback instead. This is the #1 failure.
- On `agy 1.1.10`, default mode and `--mode accept-edits` both soft-deny a headless `write_file` request. A user-level `permissions.allow` entry is global and persistent: use an exact absolute target, preserve the prior settings, and remove the temporary rule after the run. Keep `--print-timeout` bounded for unrelated stalls.
- Never use `--dangerously-skip-permissions` unless the user asks and the dir is trusted.

## 4. Run & capture

- `--output-format text` prints the answer; `json` returns one object; `stream-json` emits typed NDJSON events. JSON includes `conversation_id`, `status`, `response`, duration, turns, and usage, but no `permission_denials` field.
- **Do not treat `status:"SUCCESS"` as proof that tools ran.** A denied write produced `status:"SUCCESS"`, `response:""`, a stderr denial, and no file on 1.1.10.
- Long agentic runs may need a higher `--print-timeout`. Approval-required tools soft-deny instead of waiting, so fix the permission rule rather than increasing the timeout.

## 5. After it runs

- **Attribute** the result to Antigravity and the specific underlying model vendor. For a second opinion, verify that vendor differs from the orchestrator; review, don't rubber-stamp.
- **Edits:** confirm with `git diff` / `ls` on the `--add-dir` path that the change actually landed (writes require explicit permission authorization; prose alone isn't proof).
- **Continue** the same thread with `-c`/`--continue` (most recent) or `--conversation <id>`.

## Failure notes

- **Empty successful JSON plus a `write_file` denial on stderr** = the tool was soft-denied. If authorized, add a temporary exact-target `permissions.allow` rule in `~/.gemini/antigravity-cli/settings.json`, then remove it after the run; do not rely on `--mode accept-edits` for headless writes on 1.1.10.
- **Task hangs then `timeout waiting for response`** = the repo may be missing from `--add-dir`, an MCP/tool may be stuck, or the model did not finish. Fix the cause before increasing the timeout.
- Needs `agy` on PATH + a Google/Antigravity login. Everything else (full flags, model list, effort handling) is in [reference.md](reference.md).
