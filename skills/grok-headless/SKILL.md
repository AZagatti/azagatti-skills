---
name: grok-headless
description: "Drive xAI's Grok Build CLI non-interactively via `grok -p` (single-turn / headless) — spawn a separate Grok agent to delegate a task, get a second opinion from Grok, run a cheaper model, or produce structured JSON for scripts/CI. Invoke as `/grok-headless [model=<id>] [effort=<level>] <task>`, e.g. `/grok-headless review src/` or `/grok-headless model=grok-4.5 effort=high explain this bug`. Triggers on: grok, grok -p, grok cli, grok build, grok agent, ask grok, run grok, headless grok, delegate to grok, second opinion from grok, xai grok cli."
---

# grok-headless — driving `grok -p`

Run xAI's **Grok Build CLI** non-interactively with `grok -p` (`--single`) to spawn a separate Grok agent: delegate a self-contained task, get a second opinion from a different vendor's model, or emit structured JSON for a script. You stay the driver; read its output and act on it. This is the Grok analog of `codex-exec` and `claude-headless`, and it exists because Grok's headless flags (especially **argument ordering** and **permissions**) are easy to get silently wrong.

## Mental model (read this first)

`grok -p` is a **full agent**, not a completion — it reads files, runs shell/`git`, uses MCP + subagents, as its own session (own `sessionId`, own cost). Three things that bite:

- **`-p`/`--single` takes the prompt as its *value*.** The prompt must immediately follow `-p`; every other flag goes **before `-p`** or after the prompt. `grok -p --effort high "hi"` errors (`--single needs a value`). This is the #1 gotcha and is different from `claude -p`.
- **Headless denies file writes by default** — a write comes back `stopReason: "Cancelled"` while `text` claims success. Grant write access explicitly (below).
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
- `model=<id>` → `-m`. **Only ids from `grok models` work — an unlisted id hard-errors (`unknown model id`).** This account exposes only `grok-4.5` (default) and `grok-composer-2.5-fast`; ids from xAI's web docs (grok-4.3, grok-3-mini, …) are the raw-API surface and are **not** selectable here. No `model=` → omit it (uses the default).
- `effort=<none|minimal|low|medium|high|xhigh|max>` → `--reasoning-effort`. Support is per-model: `grok-4.5` takes `minimal`…`max` but **rejects `none`** (always reasons); `grok-composer-2.5-fast` accepts `none` (reasoning off). An unsupported level errors — see [reference.md → Models](reference.md#models-and-effort).
- `dir=<path>` → `--cwd <path>`. Default: current working directory.
- `perms=<mode>` → `--permission-mode <mode>` (explicit override of the inference below).

## 2. Pre-flight

- Resolve every file/path the task names against the target dir — actually check (`ls`/`fd`). If missing, **stop and ask** rather than firing a doomed run.
- Decide the working directory (the repo the task is about) → `--cwd`.

## 3. Pick permissions → command

**Assemble `-p "<prompt>"` as a unit; put all other flags before `-p` or after the prompt — never between.**

| Task | Permission | Command |
| ---- | ---------- | ------- |
| pure Q&A / summarize a file it just **reads** | **default** (read-only) | `grok --cwd <dir> [-m <model>] [--effort <e>] -p "<task>"` |
| **review / investigate that must run `git`/`grep`/shell**, or edit files / run tests | `--always-approve` (or `--permission-mode bypassPermissions`) | `grok --cwd <dir> --always-approve -p "<task>"` |
| granular | `--allow`/`--deny` / `--tools` | `grok --cwd <dir> --allow '<rule>' -p "<task>"` |
| `perms=<mode>` given | `--permission-mode <mode>` | explicit override |

- **Default perms allow file *reads* but deny *command execution* (`git diff`, shell, subagents) — the denied tool comes back `Cancelled` and Grok exits after its preamble (a silent no-op).** A "review the diff" task that runs `git` itself therefore **needs `--always-approve`** (verified). Only a task that Grok can finish with plain file reads — or where you paste the diff into the prompt — is safe at default.
- **`acceptEdits` does *not* approve writes/commands in headless** — use `--always-approve` or `bypassPermissions`.
- Never use `--always-approve` / `bypassPermissions` unless the user asks and the dir is trusted (they auto-approve Bash too).
- **Quoting:** the prompt is a shell arg. If it contains `"`/`` ` ``/`$`, **single-quote it** — `-p 'add a "## Notes" section'` (embedded `"` is inert in `'...'`; escape a literal `'` as `'\''`). For long/multi-line/messy prompts, use **`--prompt-file <path>`**, which *replaces* `-p` standalone: `printf '%s' "$PROMPT" > /tmp/p.txt && grok --cwd <dir> --always-approve --prompt-file /tmp/p.txt`.

## 4. Run & capture

- **Verify writes with JSON, not prose.** When the task edits files, add `--output-format json` and assert `stopReason == "EndTurn"` — a denied tool returns `stopReason: "Cancelled"` while `text` claims it wrote the file:
  ```bash
  grok --cwd <dir> --always-approve -p "<task>" --output-format json \
    | jq '{stopReason, ok:(.stopReason=="EndTurn"), text}'
  ```
  Then `git diff` to confirm the change actually landed.
- Just the answer: `grok -p "<task>" --output-format json | jq -r .text` (or plain output for a single answer).
- **Long runs:** `grok -p` is a full agentic loop — run it in the background or with a generous timeout so it isn't killed; cap turns with `--max-turns`.
- **Extras (headless-only):** `--best-of-n <N>` runs the task N ways and picks the best; `--check` appends a self-verification loop.

## 5. After it runs

- **Attribute** the result to Grok (a different vendor's model — advisory, review don't rubber-stamp).
- **Edits:** confirm `stopReason == "EndTurn"` **and** `git diff` shows the expected change — if it was `Cancelled`, re-run with `--always-approve`.
- **Continue** the same session with `-c`/`--continue` (most recent in cwd) or `-r <sessionId>` (from the JSON).

## Failure notes

- Needs `grok` on PATH + auth (`grok login`; `grok inspect` shows discovered config).
- **`--single needs a value`** = the `-p` ordering gotcha — a flag was placed between `-p` and the prompt. Fix the ordering (§3).
- **Silent no-op write** = default perms deny writes (`stopReason: "Cancelled"`, `is_error`-equivalent absent). Add `--always-approve` and check `stopReason`.
- Everything else (full flags, output fields, model/effort table) is in [reference.md](reference.md).
