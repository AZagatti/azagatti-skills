# Safety & blast radius — delegating to headless agents

Every skill in this repo drives a **full agentic loop in another CLI**. That agent can read files, run shell, use MCP servers, spawn sub-agents, and (with the wrong flag) write anywhere. This page is the shared safety contract; each skill links here instead of repeating it.

## The five rules

1. **Least privilege by default.** Start read-only. Grant writes/command-execution only for the specific task, with the narrowest flag that works:
   - Codex: `-s read-only` → `-s workspace-write` (never `danger-full-access`/`--yolo` unless the user asks).
   - Claude: default (reads only) → `--permission-mode acceptEdits`; `bypassPermissions` only when asked.
   - Grok: default → `--allow '<rule>'` (scoped) before `--always-approve`/`bypassPermissions`.
   - Antigravity: `--mode plan`/default → `--mode accept-edits`; `--dangerously-skip-permissions` only when asked.
2. **Trusted directory only for full autonomy.** `--yolo` / `--always-approve` / `--dangerously-skip-permissions` / `danger-full-access` auto-approve shell. Use them **only** in a repo you trust, and confirm with the user first — repo content can prompt-inject the delegated agent.
3. **Isolate writes.** For write runs, ensure a clean rollback point: commit/stash first, or use a fresh worktree (`git worktree`, `claude -w`, `grok -w`). Note: Codex `-s workspace-write` edits the **real workspace root** — it is *not* a rollback boundary, so isolate with a clean tree/stash/worktree first. Never launch a write run onto a dirty tree you can't cleanly separate.
4. **Verify with `git`, not prose.** The model's text ("Created the file", "tests pass") is **not** proof. After any write run: `git diff` the whole tree (writes can touch files beyond the one you named) and run the project's real test command yourself. Watch the silent-no-op signals: Claude `permission_denials`, Grok `stopReason: "Cancelled"`, Antigravity hang-to-timeout.
5. **Cap the blast radius.** Bound cost, turns, and time: Codex background + `-o`; Claude `--max-budget-usd`; Grok `--max-turns`; Antigravity `--print-timeout`. Don't delegate trivial work (a nested agentic loop can cost far more than doing it yourself).

## When NOT to delegate

- Trivial Q&A you can answer directly (a nested agent burns quota for no gain).
- The target CLI isn't authenticated / on PATH (run `scripts/doctor.sh` first).
- A dirty working tree + a write task (isolate first).
- A same-vendor loop with no added perspective (delegating Claude→Claude for a "second opinion" adds cost, not diversity — cross-vendor is the value).

## Inherited configuration (know this)

The delegated CLI runs with the **user's** environment: its `~/.codex` / `~/.claude` MCP servers, hooks, plugins, skills, credentials, and PATH tooling. These skills never disable that. Treat a delegated run as having the same reach as the user's own interactive session in that CLI.
