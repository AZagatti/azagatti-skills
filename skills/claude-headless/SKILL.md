---
name: claude-headless
description: "Drive Claude Code non-interactively with `claude -p` (headless/print mode) — a separate Claude session for delegated, cheaper/parallel, isolated, or JSON-scriptable runs. Use when the user mentions claude -p / --print, headless or SDK mode, running Claude in a script/CI/cron, or wanting structured JSON from Claude; or invokes `/claude-headless [model=<alias>] [effort=<level>] <task>`."
---

# claude-headless — driving `claude -p`

Run Claude Code non-interactively with `claude -p` to spawn a **separate** Claude session: delegate a self-contained task, run a cheaper/faster model in parallel, get isolated fresh-context output, or emit structured JSON for a script. You stay the driver; read its output and act on it. This skill exists because the headless flags (especially **permissions** and **output format**) are easy to forget and get silently wrong.

## Mental model (read this first)

`claude -p` is a **full agent**, not a text completion — it reads files, runs shell/`git`, uses MCP + skills, in whatever directory you launch it from, as its **own session** (own context, own cost, own `session_id`). Three things that bite:

- **No `-C` flag — the working directory is the launch cwd.** Point it at a repo by launching there: `(cd <repo> && claude -p "…")`. `--add-dir <path>` grants extra access.
- **Headless perms are restrictive by default.** A tool that would prompt interactively is **denied** in `-p` mode — *and the run still exits `is_error: false`*. A "write the file" task can report success while writing nothing. Choose a permission mode deliberately and verify (below).
- **It's a fresh session** — it does **not** see this conversation. Put everything it needs in the prompt (name files/paths; it reads them itself).

## Quick reference

| Need | Where |
| ---- | ----- |
| **Permission model** (default vs acceptEdits vs bypass) | [reference.md → Permissions](reference.md#permission-model-the-most-forgotten-part) |
| All flags | [reference.md → Key flags](reference.md#key-flags) |
| Output shape (`text`/`json`/`stream-json`, `.result`, `permission_denials`) | [reference.md → Output](reference.md#output-shape) |
| Models + `--effort` | [reference.md → Models](reference.md#models-and-effort) |
| Sessions / resume, `--bare`, cost | [reference.md → Key flags](reference.md#key-flags) |

## 1. Parse the invocation

Called with a free-form task, optionally prefixed by `key=value` options:

```
/claude-headless model=haiku summarize server.log and list the top 5 error types
/claude-headless model=sonnet effort=low review the changes in src/
/claude-headless dir=../other-repo explain how auth flows through the codebase
```

- **Options are only the *contiguous leading* tokens whose key is `model`, `effort`, `dir`, or `perms`.** Stop at the first token that isn't one of those `key=value` forms — the rest is the **task**, verbatim (so an `=` inside the task is preserved).
- `model=<alias|id>` → `--model` (aliases: `opus`/`sonnet`/`haiku`/`fable`, or a full id). No `model=` → omit it (inherits parent/config model). Never invent an id.
- `effort=<low|medium|high|xhigh|max>` → `--effort`.
- `dir=<path>` → launch in that dir (`cd`) and/or `--add-dir`. Default: current working directory.
- `perms=<mode>` → `--permission-mode <mode>` (explicit override of the role inference below).

## 2. Pre-flight

- Resolve every file/path the task names against the launch dir — actually check (`ls`/`fd`). If missing, **stop and ask** rather than delegating a doomed run.
- Decide the working directory (the repo the task is about) — `claude -p` uses cwd, so launch it there.

## 3. Pick permissions → command

Infer the least privilege that lets the task finish:

| Task | Permission | Command |
| ---- | ---------- | ------- |
| read / analyze / summarize / review / "explain" / answer a question | **default** (read tools only) | `(cd <dir> && claude -p [--model <m>] [--effort <e>] "<task>")` |
| must edit files | `--permission-mode acceptEdits` | `(cd <dir> && claude -p --permission-mode acceptEdits [--model <m>] "<task>")` |
| must also run mutating shell/tests | `--allowedTools` (granular) or `--permission-mode bypassPermissions` | prefer `--allowedTools "Edit Bash(npm test)"` over a blanket bypass |
| user explicitly wants full autonomy in a trusted/sandboxed dir | `--dangerously-skip-permissions` | confirm with the user first |
| `perms=<mode>` given | that mode | explicit override wins |

- Default to **read-only** (no permission flag) unless the task must change files. Most delegations (summarize, review, investigate) are read-only.
- Never use `--dangerously-skip-permissions` / `bypassPermissions` unless the user asks and the dir is trusted.
- The `"<task>"` in the templates above is shorthand — actually pass the task via the **quoted heredoc** in §4 so embedded quotes/`$`/backticks don't break the command.

## 4. Run & capture

- **Quote the task safely.** The task is inserted verbatim and may contain `"`, `` ` ``, `$`, or `'` — do **not** paste it into a double-quoted `"<task>"` (it will shell-break). Pass it via a **quoted heredoc** (nothing is interpreted), which is the form the templates below assume:
  ```bash
  (cd <dir> && claude -p --permission-mode acceptEdits --model <m> --output-format json <<'PROMPT'
  <task text, verbatim — quotes/backticks/$ all safe>
  PROMPT
  ) | jq '{is_error, denials:[.permission_denials[]?.tool_name], cost:.total_cost_usd, result}'
  ```
  (Single-quoting the arg with `'\''`-escaping works too, but the heredoc avoids all escaping.)
- **Verify changes with JSON, not prose.** When the task edits files, use `--output-format json` and assert `permission_denials` is empty — a denied tool leaves `is_error:false` while doing nothing (the `jq` above surfaces both).
- Just the answer: `claude -p "<task>" --output-format json | jq -r .result` (or plain `text` output for a single answer).
- **Long runs:** `claude -p` is a full agentic loop — run it in the background or with a generous timeout so it isn't killed by a default tool timeout. Cap spend with `--max-budget-usd`.
- **Cheap/isolated:** add `--bare` to skip CLAUDE.md/hooks/auto-memory for a clean, cheaper context-free run (then pass context explicitly via `--add-dir`/`--system-prompt`).

## 5. After it runs

- **Attribute** the result to the spawned Claude session; if it used a different/cheaper model, treat its output as advisory and review it.
- **Edits:** confirm `permission_denials` was empty **and** `git diff` shows the expected change — don't trust `.result` text. If files were denied, re-run with the right `--permission-mode`.
- **Continue** the same session with `--resume <session_id>` (from the JSON) or `--continue` (most recent in cwd).

## Failure notes

- Needs `claude` on PATH + auth (`claude doctor`). It reuses your Claude Code auth; `--bare` needs `ANTHROPIC_API_KEY`.
- **Silent no-op on writes** is the #1 trap: default perms deny Edit/Write, `is_error` stays false. Use `--permission-mode acceptEdits` (or `--allowedTools`) and check `permission_denials`.
- Everything else (full flag list, output fields, model ids, cost) is in [reference.md](reference.md).
