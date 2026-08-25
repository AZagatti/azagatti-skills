---
name: opencode-run
description: "Drive opencode non-interactively with `opencode run` (headless) — a separate agent over a model only the user's own providers reach (a z.ai GLM coding plan, Amazon Bedrock, anything in `opencode models`). Use when the user mentions opencode, wants a second opinion from a provider the other headless CLIs cannot reach, or invokes `/opencode-run [model=<provider/model>] [agent=plan|build] [variant=<level>] [dir=<path>] <task>`."
---

# opencode-run — driving `opencode run`

Run **opencode** non-interactively with `opencode run` to spawn a separate agent on **whatever provider the user has connected** — a z.ai GLM coding plan, Amazon Bedrock, or any other entry in `opencode models`. This is the bring-your-own-provider member of the headless family, next to `codex-exec` / `claude-headless` / `grok-headless` / `agy-headless`. It exists because opencode's default agent is **write-enabled with no flag**, which is the opposite of every other CLI here.

## Mental model (read this first)

`opencode run` is a **full agent**, not a completion, and it runs as its own session against a provider you configured. Three things that bite, all different from the other headless CLIs:

- **It writes files and runs shell without `--auto`.** The default `build` agent carries `{"permission": "*", "action": "allow"}` — on 1.18.23 a plain `opencode run` created a file and ran `bash` with no approval flag and no prompt. `--auto` is not the switch that unlocks writes; it is already unlocked. **For any read-only task, pass `--agent plan`.**
- **The model is `provider/model`, and the provider must be connected.** `opencode models` is the source of truth. An unknown model or provider exits **1** with a JSON `UnknownError` blob, so check the exit code.
- **stdout is clean.** The `> build · glm-5.3` header and every tool line go to **stderr**; stdout carries only the final answer. `opencode run "…" 2>/dev/null` is a usable one-liner, unlike `codex exec`.

## Quick reference

| Need | Where |
| ---- | ----- |
| **Permissions** (write-enabled by default — the #1 gotcha) | [reference.md → Permissions](reference.md#permissions-and-agents-the-1-gotcha) |
| Connecting a provider (z.ai GLM, Bedrock) | [reference.md → Providers](reference.md#providers-and-credentials) |
| All flags | [reference.md → Key flags](reference.md#key-flags) |
| Output shape (`default`/`json`, event types, cost) | [reference.md → Output](reference.md#output-shape) |
| Models + `--variant` | [reference.md → Models](reference.md#models-and-variants) |

## 1. Parse the invocation

Called with a free-form task, optionally prefixed by `key=value` options:

```
/opencode-run review the changes in src/
/opencode-run model=zai-coding-plan/glm-5.3 explain why this test flakes
/opencode-run model=zai-coding-plan/glm-5-turbo dir=../repo summarize the architecture
/opencode-run agent=plan variant=high audit this module for race conditions
```

- **Options are only the *contiguous leading* tokens whose key is `model`, `variant`, `dir`, or `agent`.** Stop at the first non-matching token — the rest is the **task**, verbatim (an `=` inside the task is preserved).
- `model=<provider/model>` → `-m`. Always `provider/model`, never a bare model name. No `model=` → omit it and let the config default apply (`model` in `~/.config/opencode/opencode.json`).
- `variant=<level>` → `--variant`. Provider-specific reasoning effort; not validated (§Failure notes).
- `dir=<path>` → `--dir <path>`. Default: current working directory.
- `agent=<name>` → `--agent`. `plan` for read-only, `build` for edits. `opencode agent list` shows the rest.

## 2. Pre-flight

- Resolve every file/path the task names against the target dir — actually check (`ls`/`fd`). If missing, **stop and ask** rather than firing a doomed run.
- Confirm the model is reachable: `opencode models <provider>`.
- Decide the working directory (the repo the task is about) → `--dir`.

## 3. Pick an agent → command

**The agent is the permission boundary. Choose it before you choose anything else.**

| Task | Agent | Command |
| ---- | ----- | ------- |
| review / Q&A / audit — **must not write** | `plan` | `opencode run --dir <dir> --agent plan [-m <provider/model>] "<task>"` |
| implement, edit files, run tests | `build` (default) | `opencode run --dir <dir> [-m <provider/model>] "<task>"` |
| script or CI consuming events | either | add `--format json` and parse the event stream |

- **`--agent plan` is the verified read-only lever.** Asked to create a file on 1.18.23, it declined ("Plan mode is active, so I can't create the file yet"), returned a plan, and wrote nothing.
- **`build` is not a sandbox.** It is allow-all: it writes files and runs shell commands unprompted. Only point it at a directory the user authorized, and never at a repo with uncommitted work you cannot inspect afterwards.
- Do not add `--auto` unless the user asks. It only widens an already-open surface ("auto-approve permissions that are not explicitly denied (dangerous!)").
- **There is no `--max-turns` and no budget flag.** Cap the blast radius with the agent choice, the directory, and a timeout — not with a turn limit.
- **`--share` shares the session** (untested here — the help text says "share the session"). Never pass it on private code without an explicit request.
- **Quoting:** the prompt is a positional argument, so no flag-ordering trap exists. Still single-quote a prompt containing `"`/`` ` ``/`$`, and escape a literal `'` as `'\''`.
- **Long or multi-line prompts:** both paths work on 1.18.23 — pass the whole thing as one single-quoted positional argument (newlines survive), or pipe it on **stdin** (`printf '%s' "$PROMPT" | opencode run --agent plan`). There is no `--prompt-file`.

## 4. Run & capture

- Just the answer, default format:
  ```bash
  opencode run --dir <dir> --agent plan "<task>" 2>/dev/null
  ```
- Just the answer, JSON:
  ```bash
  opencode run --dir <dir> --agent plan --format json "<task>" 2>/dev/null \
    | jq -r 'select(.type=="text") | .part.text'
  ```
- **Verify writes with `git diff`, not prose.** `--format json` emits a `tool_use` event per call (`.part.tool`, `.part.state.status`, `.part.state.metadata.exit`), which tells you what it *attempted*. Only the diff tells you what landed.
- **`cost` is not money spent.** The `step_finish` event reports `0` on the z.ai coding plan and the free `opencode/*` tier, and a non-zero figure on opencode Go — but Go is a subscription with reset windows, so that figure is a notional token price, not a charge. On either plan the limit that bites is the reset window, not a dollar total. Budget from `tokens.total`, which was populated on every provider tested here.
- **Long runs:** it is a full agentic loop. Run it in the background or with a generous timeout.

## 5. After it runs

- **Attribute** the result to the model you selected (say "GLM-5.3 via opencode", not "opencode"). A second opinion is only cross-vendor if the provider differs from the orchestrator.
- **Edits:** confirm exit code `0` **and** `git diff` shows the expected change. Prose claiming success is not evidence.
- **Continue** the same session with `-c` (last session in that directory) or `-s <sessionID>` from the JSON events. Verified: a fact stated in one run was recalled by the next `-c` run.

## Failure notes

- Needs `opencode` on PATH and a connected provider. `opencode auth list` shows stored credentials and env-detected providers; `opencode models` shows what is actually selectable.
- **Exit 1 with a JSON `UnknownError` blob** = unknown model or provider. Re-check `opencode models <provider>` for the exact `provider/model` string.
- **A `--variant` typo does not fail.** `--variant bogus-level` exited 0 and ran the request; nothing in the output reports the applied variant. Copy variant names from the provider's documentation and treat a wrong one as silently ignored.
- **An unwanted file change** = the `build` agent did what it is allowed to do. Re-run read-only tasks with `--agent plan`.
- Follow the shared blast-radius rules in [safety.md](https://github.com/AZagatti/azagatti-skills/blob/main/docs/safety.md).
- Everything else (flags, provider setup, event shapes, model table) is in [reference.md](reference.md).
