---
name: codex-exec
description: "Drive OpenAI's Codex CLI (`codex exec`) as a second agentic model — implement, review a branch/PR, investigate, or give a cross-vendor second opinion. Use when the user asks to run or ask Codex, get a Codex PR review, or wants an OpenAI second opinion; or invokes `/codex-exec [model=<id>] <task>`."
---

# codex-exec — Codex as an auxiliary

Run OpenAI's **Codex CLI** non-interactively (`codex exec`) to hand a self-contained task to a second model, read its output, and act on it. Codex is the **auxiliary**; you stay the driver. One entry point covers every role — implement-alongside, review, investigate, second opinion — inferred from the instruction.

## Mental model (read this first)

**Codex `exec` is itself an agent, not a text completion.** Point it at a directory with `-C` and it reads files, runs `git`/`gh`, and executes commands **in your login shell** — so it has your PATH tooling (`gh`, `rg`, test runners, package managers, …) plus the user's `~/.codex` **MCP servers, plugins, skills, and hooks**. Two rules follow:

- **Give it a goal + a workspace, not pasted content.** Name the files/paths/branch; Codex reads them itself. Only pipe content via stdin when it lives *outside* the workspace (e.g. a diff against a remote).
- **It can act.** In `read-only` it can inspect anything (files, git history, GitHub via `gh`) but not write; in `workspace-write` it edits real files **anywhere under the workspace root — not just the file you named**. Choose the sandbox deliberately (below).

## Quick reference

| Need | Where |
| ---- | ----- |
| Exact flags / values | [reference.md → Flags](reference.md#flags-and-options) |
| Sandbox modes | [reference.md → Sandbox](reference.md#sandbox-and-approval-modes-pick-the-least-privilege-that-works) |
| **Review a branch/PR** (`review --base` / `--uncommitted`) | [reference.md → Subcommands](reference.md#subcommands) |
| Resume / apply Codex's diff | [reference.md → Subcommands](reference.md#subcommands) |
| Output shape, capturing just the answer | [reference.md → Output](reference.md#output-modes-and-shape) |
| Model / auth errors | [reference.md → Model and auth](reference.md#model-and-auth-notes) |
| Available models + reasoning effort | [reference.md → Models](reference.md#available-models-and-reasoning-effort) |

## 1. Parse the invocation

Called with a free-form instruction, optionally prefixed by `key=value` options:

```
/codex-exec model=gpt-5.6-terra be my auxiliary implementing the rate limiter in src/limit.ts
/codex-exec model=gpt-5.6-sol review your PR
/codex-exec ask it whether db/2026_add_index.sql is a safe migration
```

- **Options are only the *contiguous leading* tokens whose key is `model`, `sandbox`, or `dir`.** Stop at the first token that isn't one of those `key=value` forms — everything from there on is the **instruction**, verbatim. (So `fix the x=y comparison bug` keeps `x=y` in the instruction; only a leading `model=`/`sandbox=`/`dir=` is consumed.)
- **No `model=`** → omit `-m`; Codex uses its configured default. Never invent a model id; pass what the user typed straight to `-m`. (Model list + per-model reasoning tiers: [reference.md → Models](reference.md#available-models-and-reasoning-effort). Reasoning is **off by default** in `exec`; dial it with `-c model_reasoning_effort="high"` — or `="none"` to force off. Exception: `gpt-5.3-codex-spark` **requires** an effort ≥ `low`, so it fails without the flag.)
- Map `dir=<path>` → `-C <path>`. If absent, default `-C` to the **repo root / current working directory**.

## 2. Pre-flight (hard gate — build a §3 command only after this passes)

- **Files:** resolve every path the instruction names against `-C` — actually check (`ls <path>` / `fd <name>`), don't eyeball. If one doesn't exist, **stop and ask** which repo/dir it's in (or whether the filename is wrong) — don't fire a prompt aimed at a missing file.
- **Branch/PR review:** confirm there's a real diff before delegating:
  ```bash
  git -C <repo> rev-parse --abbrev-ref HEAD      # current branch
  git -C <repo> log --oneline <base>..HEAD       # commits ahead of base
  git -C <repo> status --porcelain               # uncommitted + untracked
  ```
  If current branch == base **and** both are empty → stop, tell the user there's nothing to review. Base branch is usually `main`; if unsure, resolve with `git symbolic-ref refs/remotes/origin/HEAD` or ask.

## 3. Pick the role → command

| Instruction | Command shape | Sandbox |
| ----------- | ------------- | ------- |
| **Review your branch/PR** | `codex exec -C <repo> review --base <base>` (committed branch work) **or** `--uncommitted` (local staged/unstaged/untracked) `[-m <model>]` | (review is read-only by nature) |
| review / investigate / "is X safe" / a question / second opinion | `codex exec [-m <model>] -s read-only -C <repo> "<goal, naming the files>"` | `read-only` |
| "be my auxiliary implementing…" / help write code | `codex exec [-m <model>] -s read-only -C <repo> "<goal + point at existing files>; propose a diff/full file, don't write — I'll apply it"` | `read-only` |
| user explicitly wants Codex to edit files itself | add `-s workspace-write` | `workspace-write` |
| `sandbox=<mode>` given | use that mode (explicit override wins) | as given |

- **Which review flag:** committed work on a branch vs a base → `--base <base>`; uncommitted/untracked local changes → `--uncommitted` (`--base` won't see untracked files). Unsure which the user means → check `git status` in pre-flight and pick, or run both.
- **A literal GitHub PR** ("review PR #123") → Codex can fetch it via `gh`; say so in the instruction, e.g. `codex exec -C <repo> review "review PR #123 (use gh to fetch it)"`.
- `-C` **must precede `review`**: `codex exec -C <repo> review …` (putting `-C` after `review` errors).
- Add `--skip-git-repo-check` only if it may run outside a Git repo.
- Never use `--yolo` / `danger-full-access` unless the user explicitly demands it and accepts the risk.

## 4. Run & capture

- Default output is **chatty** (header, `hook:` lines, `tokens used`); the real answer is the final message. For scripts/clean capture add `-o <file>` (final message only) or `--json` (structured events).
- **Quote the instruction safely.** It may contain `"`, `` ` ``, `$`, or `'` — don't paste it into a double-quoted arg (it will shell-break). Pass it via a **quoted heredoc** on stdin (Codex reads `-` from stdin), which also handles long/multi-line prompts:
  ```bash
  codex exec -s read-only -C <repo> - <<'PROMPT'
  <instruction, verbatim — quotes/backticks/$ all safe>
  PROMPT
  ```
- **Codex is a full agentic loop — runs can take minutes.** Run it in the background (or with a generous timeout) so it doesn't stall or get killed by a default tool timeout; capture to `-o <file>` and read the file when it finishes.
- If you ran **both** `review --base` and `review --uncommitted` (mixed committed + untracked work), they're two separate invocations — merge their findings into one review for the user and note any overlap.

## 5. After it runs

- **Attribute** the result to Codex (a different model — advisory, not authoritative) and summarize the useful parts.
- **Auxiliary/implement:** review its proposed diff critically, then **you** apply it (or `codex apply` to apply its last diff). Don't have both you and Codex editing the same file — consult Codex first, then implement.
- **workspace-write — before running:** ensure a clean rollback point (commit/stash so `git status` is clean, or `git stash create` a snapshot). Don't launch a write run onto a dirty tree you can't cleanly separate afterward.
- **workspace-write / "fix the tests" — after Codex exits:** independently run `git diff` (see everything it touched, workspace-wide) and the project's **actual test command** — never relay Codex's self-reported "tests pass". Also confirm the fix is *real*: check it didn't make tests green by weakening assertions, skipping, or `xfail`-ing them.
- Continue the same thread with `codex exec resume --last "<follow-up>"`.

## Failure notes

- Needs `codex` on PATH + auth (`codex doctor` to check). On an auth error, tell the user to run `! codex login` (interactive).
- **Unsupported model** (ChatGPT-account auth) fails with `400 invalid_request_error … "not supported when using Codex with a ChatGPT account"` — surface it and suggest a supported model; don't silently retry.
- Everything else (per-run feature/MCP scoping, config overrides, exact error strings) is in [reference.md](reference.md).
