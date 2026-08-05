---
name: grok-headless
description: "Drive xAI's Grok Build CLI non-interactively with `grok -p` (headless) — a separate Grok agent for a delegated task, a cross-vendor second opinion, a cheaper model, or JSON output. Use when the user asks to run or ask Grok, mentions grok -p / Grok Build, or wants a Grok second opinion; or invokes `/grok-headless [model=<id>] [effort=<level>] <task>`."
---

# grok-headless — driving `grok -p`

Run xAI's **Grok Build CLI** non-interactively with `grok -p` (`--single`) to spawn a separate Grok agent: delegate a self-contained task, get a second opinion from a different vendor's model, or emit structured JSON for a script. You stay the driver; read its output and act on it. This is the Grok analog of `codex-exec` and `claude-headless`, and it exists because Grok's headless flags (especially **argument ordering** and **permissions**) are easy to get silently wrong.

## Mental model (read this first)

`grok -p` is a **full agent**, not a completion — it reads files, runs shell/`git`, uses MCP + subagents, as its own session (own `sessionId`, own cost). Three things that bite:

- **`-p`/`--single` takes the prompt as its *value*.** The prompt must immediately follow `-p`; every other flag goes **before `-p`** or after the prompt. `grok -p --effort high "hi"` errors (`--single needs a value`). This is the #1 gotcha and is different from `claude -p`.
- **Headless cannot stop for an interactive approval.** Effective defaults depend on project trust, settings, and rules; use explicit scoped rules for deterministic automation and verify `stopReason` plus side effects.
- **Fresh session, explicit cwd.** It doesn't see this conversation — name files/paths in the prompt. Point it at a repo with `--cwd <dir>`.

## Quick reference

| Need | Where |
| ---- | ----- |
| **Argument ordering** (the `-p` value gotcha) | [reference.md → ordering](reference.md#argument-ordering-the-1-gotcha) |
| **Permission model** (default denies writes) | [reference.md → Permissions](reference.md#permission-model-the-most-forgotten-part) |
| All flags | [reference.md → Key flags](reference.md#key-flags) |
| Output shape (`plain`/`json`, `stopReason`, `text`) | [reference.md → Output](reference.md#output-shape) |
| Models + effort (`grok models`) | [reference.md → Models](reference.md#models-and-effort) |

## 1. Parse the invocation

Called with a free-form task, optionally prefixed by `key=value` options:

```
/grok-headless review the changes in src/
/grok-headless model=grok-4.5 effort=high explain why this test flakes
/grok-headless dir=../other-repo summarize the architecture
```

- **Options are only the *contiguous leading* tokens whose key is `model`, `effort`, `dir`, or `perms`.** Stop at the first non-matching token — the rest is the **task**, verbatim (an `=` inside the task is preserved).
- `model=<id>` → `-m`. Use an account-visible id from `grok models` or a configured custom-model key; do not copy raw API model names blindly. This account currently exposes only `grok-4.5`.
- `effort=<low|medium|high>` → `--reasoning-effort`. Grok 4.5 reasons at every tier and defaults to `high`; the current CLI rejects other values.
- `dir=<path>` → `--cwd <path>`. Default: current working directory.
- `perms=<mode>` → `--permission-mode <mode>` (explicit override of the inference below).

## 2. Pre-flight

- Resolve every file/path the task names against the target dir — actually check (`ls`/`fd`). If missing, **stop and ask** rather than firing a doomed run.
- Decide the working directory (the repo the task is about) → `--cwd`.

## 3. Pick permissions → command

**Assemble `-p "<prompt>"` as a unit; put all other flags before `-p` or after the prompt — never between.**

| Task | Permission | Command |
| ---- | ---------- | ------- |
| pure Q&A / read-only review | project defaults, preferably `dontAsk` + scoped read rules | `grok --cwd <dir> [--permission-mode dontAsk] [-m <model>] [--effort <e>] -p "<task>"` |
| edit files, keep shell gated | `acceptEdits` plus scoped shell rules if needed | `grok --cwd <dir> --permission-mode acceptEdits -p "<task>"` |
| deterministic granular automation | `--allow`/`--deny` / `--tools` | `grok --cwd <dir> --permission-mode dontAsk --allow '<rule>' -p "<task>"` |
| `perms=<mode>` given | `--permission-mode <mode>` | explicit override |

- Default behavior is not universal: on the trusted audited project with no loaded rules, a direct read and read-only `pwd` both ran. Enterprise policy, persisted rules, trust, and tool classification can change that.
- Current xAI docs define `acceptEdits` as auto-approving file edits while shell commands remain gated. Prefer `dontAsk` plus narrow `--allow` rules when a script must fail closed.
- Never use `--always-approve` / `bypassPermissions` unless the user asks and the dir is trusted (they auto-approve Bash too).
- **Quoting:** the prompt is a shell arg. If it contains `"`/`` ` ``/`$`, **single-quote it** — `-p 'add a "## Notes" section'` (embedded `"` is inert in `'...'`; escape a literal `'` as `'\''`). For long/multi-line/messy prompts, use **`--prompt-file <path>`**, which *replaces* `-p` standalone: `printf '%s' "$PROMPT" > /tmp/p.txt && grok --cwd <dir> --always-approve --prompt-file /tmp/p.txt`.

## 4. Run & capture

- **Verify writes with JSON, not prose.** When the task edits files, add `--output-format json` and assert the current successful terminal value `stopReason == "end_turn"`:
  ```bash
  grok --cwd <dir> --always-approve -p "<task>" --output-format json \
    | jq '{stopReason, ok:(.stopReason=="end_turn"), text}'
  ```
  Then `git diff` to confirm the change actually landed.
- Just the answer: `grok -p "<task>" --output-format json | jq -r .text` (or plain output for a single answer).
- **Long runs:** `grok -p` is a full agentic loop — run it in the background or with a generous timeout so it isn't killed; cap turns with `--max-turns`.

## 5. After it runs

- **Attribute** the result to Grok (a different vendor's model — advisory, review don't rubber-stamp).
- **Edits:** confirm `stopReason == "end_turn"` **and** `git diff` shows the expected change. Any other terminal reason or missing diff is a failed run even if the prose claims success.
- **Continue** the same session with `-c`/`--continue` (most recent in cwd) or `-r <sessionId>` (from the JSON).

## Failure notes

- Needs `grok` on PATH + auth (`grok login`; `grok inspect` shows discovered config).
- **`--single needs a value`** = the `-p` ordering gotcha — a flag was placed between `-p` and the prompt. Fix the ordering (§3).
- **Silent no-op write** = inspect `stopReason`, stderr, active permission rules, and `git diff`; then add the narrowest missing allow-rule.
- Everything else (full flags, output fields, model/effort table) is in [reference.md](reference.md).
