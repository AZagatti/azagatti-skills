---
name: agy-headless
description: "Drive Google's Antigravity CLI with `agy -p` (headless) — a separate multi-vendor agent (Gemini / Claude / GPT-OSS via one login) for a delegated task, cross-vendor second opinion, or cheaper model. Use when the user mentions agy or Antigravity (the Gemini CLI successor), or wants to delegate to Gemini/Antigravity; or invokes `/agy-headless [model=<name>] [dir=<path>] <task>`."
---

# agy-headless — driving `agy -p` (Antigravity)

Run Google's **Antigravity CLI** non-interactively with `agy -p` to spawn a separate agent — a **multi-vendor aggregator** (one login → Gemini, Claude, and GPT-OSS models). The headless analog of `codex-exec` / `claude-headless` / `grok-headless`, and the successor to Gemini CLI. This skill exists because `agy` has a **very different workspace and permission model** that silently no-ops or hangs if you get it wrong.

## Mental model (read this first)

`agy -p` is a **full agent**, not a completion, and picks from Gemini/Claude/GPT-OSS behind one Google login. Three gotchas, all unlike the other headless CLIs:

- **No cwd — it works in an isolated scratch dir by default and can't see your files.** You MUST pass **`--add-dir <path>`** to mount your repo. Without it, a file-reading task **hangs until the 5-minute timeout** and writes go to `~/.gemini/antigravity-cli/scratch/`, not your directory. (Verified.)
- **Effort is baked into the model name**, not a flag: `Gemini 3.5 Flash (High)` vs `(Low)`. No `--effort`.
- **Plain-text output only** (no JSON), and it **hangs on tools it can't auto-approve** — so agentic work needs a permission flag *and* a bounded timeout.

## Quick reference

| Need | Where |
| ---- | ----- |
| **`--add-dir`** (the #1 gotcha) | [reference.md → files](reference.md#giving-it-your-files---add-dir-the-1-gotcha) |
| **Permissions** (default hangs on tools) | [reference.md → Permissions](reference.md#permissions) |
| All flags | [reference.md → Key flags](reference.md#key-flags) |
| Models + effort-in-the-name | [reference.md → Models](reference.md#models-and-effort) |

## 1. Parse the invocation

Called with a free-form task, optionally prefixed by `key=value` options:

```
/agy-headless dir=. review the changes in src/
/agy-headless model="Claude Opus 4.6 (Thinking)" explain why this test flakes
/agy-headless dir=../repo model="Gemini 3.1 Pro (High)" summarize the architecture
```

- **Options are only the *contiguous leading* tokens whose key is `model`, `dir`, or `mode`.** Stop at the first non-matching token — the rest is the **task**, verbatim.
- `model=<name>` → `--model` with the **exact display string** from `agy models` (quote it — it has spaces/parens: `--model "Gemini 3.5 Flash (High)"`). No `model=` → omit (uses the default). Effort = pick a `(Low|Medium|High)` variant; there's no `--effort`.
- `dir=<path>` → **`--add-dir <path>`** (repeatable). **Default `dir` to the repo you want it to work on — never omit it for a file task**, or the run hangs/no-ops.
- `mode=<accept-edits|plan>` → `--mode`.

## 2. Pre-flight

- Resolve the file/dir the task is about; that path is what you pass to `--add-dir`. If the task touches files and you have no dir, **ask** rather than firing a run that will hang in the scratch sandbox.

## 3. Build the command

**Always:** `--add-dir <repo>` for any task about your files, `-p "<prompt>"` last, a permission flag if it must act, and a bounded `--print-timeout`.

| Task | Command |
| ---- | ------- |
| read / analyze / review / question | `agy --add-dir <repo> [--model "<name>"] --print-timeout 3m -p "<task>"` |
| must edit files | add `--mode accept-edits` |
| full autonomy (files + commands) in a trusted dir | add `--dangerously-skip-permissions` (confirm with user first) |

- **Without `--add-dir` the agent can't see your files** → it searches, blocks, and times out. This is the #1 failure.
- **Default (no `--mode`/skip-permissions) hangs on the first tool that needs approval** — for anything agentic, pass `--mode accept-edits` or `--dangerously-skip-permissions`. Keep `--print-timeout` bounded (e.g. `3m`) so a stuck run fails fast instead of burning the 5m default.
- Never use `--dangerously-skip-permissions` unless the user asks and the dir is trusted.

## 4. Run & capture

- Output is **plain text** on stdout (no JSON) — capture it directly; there's no `stopReason` object. `agy -p "<task>" | tail` for the answer.
- Long agentic runs: raise `--print-timeout`; but if you expect it to hang on approval, add the permission flag instead of just waiting.

## 5. After it runs

- **Attribute** the result to Antigravity + the specific model (Gemini/Claude/GPT-OSS — a different vendor; review, don't rubber-stamp).
- **Edits:** confirm with `git diff` / `ls` on the `--add-dir` path that the change actually landed (writes only apply with a permission flag; prose alone isn't proof).
- **Continue** the same thread with `-c`/`--continue` (most recent) or `--conversation <id>`.

## Failure notes

- **Task hangs then `timeout waiting for response`** = missing `--add-dir` (can't find your files) and/or an unapproved tool. Add `--add-dir <repo>` and a permission flag (`--mode accept-edits` / `--dangerously-skip-permissions`); lower `--print-timeout` to fail fast.
- **"It said it created the file but it's not there"** = no permission flag (write not applied) or it wrote to `~/.gemini/antigravity-cli/scratch/` because `--add-dir` was missing.
- Needs `agy` on PATH + a Google/Antigravity login. Everything else (full flags, model list, effort-in-name) is in [reference.md](reference.md).
