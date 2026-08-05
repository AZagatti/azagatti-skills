# Headless CLI comparison & chooser

The four skills document four CLIs that all do "run an agent non-interactively." This page is the **cross-cutting view** — pick the right one, and translate one mental model across their different flag dialects. Every fact here is verified in the individual skills' `reference.md`; CLI versions tested: `codex 0.145.0`, `claude 2.1.220`, `grok 0.2.118`, `agy 1.1.10`.

## At a glance

| | **codex-exec** (OpenAI) | **claude-headless** (Anthropic) | **grok-headless** (xAI) | **agy-headless** (Google Antigravity) |
|---|---|---|---|---|
| Headless command | `codex exec` | `claude -p` | `grok -p` | `agy -p` |
| Prompt delivery | arg or `-` stdin | arg or stdin | **prompt is `-p`'s value** (ordering gotcha) or `--prompt-file` | `-p` / `--print` / `--prompt` |
| Workspace | `-C <dir>` | launch **cwd** (+ `--add-dir`) | `--cwd <dir>` | **none → `--add-dir` required** (else isolated scratch) |
| Default write policy | read-only/configured | reads OK, prompt-class tools denied | reads OK, command/write tools denied | denied in headless, including `--mode accept-edits` on 1.1.10 |
| Silent-fail signal | command error / failed JSONL event | `permission_denials[]`, often `is_error:false` | non-`end_turn` stop reason or missing side effect | stderr denial + empty response while JSON says `status:"SUCCESS"` |
| Grant writes | `-s workspace-write` | `--permission-mode acceptEdits` or scoped rules | scoped permission rule; `--always-approve` only when authorized | scoped `permissions.allow`; dangerous bypass only when authorized |
| Structured output | `--json` (JSONL events); `-o` = final message | `--output-format json` (`.result` / `.structured_output`) | `--output-format json` (`.text/.thought/.stopReason`) | `--output-format json` or `stream-json` |
| Reasoning effort | `-c model_reasoning_effort` (config/model-specific) | `--effort` (per-model) | `--reasoning-effort` (per-model) | `--effort low\|medium\|high` |
| Session resume | `codex exec resume` | `--resume` / `--continue` | `-c` / `-r <id>` | `-c` / `--conversation <id>` |
| Built-in PR review | `review --base`/`--uncommitted` | `claude ultrareview [target]` (cloud, billed/entitled) | — | — |
| Web search | via `gh`/tools | yes | yes | not documented |

## Which one?

```
Need a second opinion from a DIFFERENT vendor than you're running?
├── OpenAI depth on a repo / real PR review ......... codex-exec  (review --base)
├── xAI cross-vendor take on a diff ................. grok-headless
└── Gemini / Claude / GPT-OSS behind ONE login ...... agy-headless

Need structured JSON to script against? ............. claude-headless / grok-headless / agy-headless (single-result JSON), or codex-exec --json (JSONL events)
Need cheap/parallel bulk work? ...................... claude-headless --model haiku  (or a cheap model on any)
Need it to actually EDIT files / run tests? ......... codex-exec -s workspace-write  (strongest repo tooling)
Multi-model comparison from one tool? ............... agy-headless  (`agy models` spans multiple vendors)
```

**The killer app is cross-vendor disagreement** — run two vendors on the same diff and merge findings (see the quorum recipe in the [`headless-delegate`](../skills/headless-delegate/SKILL.md) skill). Delegating a model to *itself* adds cost, not perspective.

## One vocabulary, four dialects

When a skill takes `key=value` options, map this shared vocabulary to each CLI:

| Intent | codex | claude | grok | agy |
|--------|-------|--------|------|-----|
| **dir** (workspace) | `-C` | cwd / `--add-dir` | `--cwd` | `--add-dir` |
| **model** | `-m` | `--model` | `-m` (account model id or custom-model key) | `--model <base-or-emitted-slug>` |
| **effort** | `-c model_reasoning_effort=` | `--effort` | `--reasoning-effort` | `--effort` |
| **access** (let it write/run) | `-s workspace-write` | `--permission-mode acceptEdits` | scoped rule / `--always-approve` | scoped `permissions.allow` / dangerous bypass |
| **timeout / budget** | background + `-o` | `--max-budget-usd` | `--max-turns` | `--print-timeout` |

> ⚠️ The option **keys differ by skill** on purpose (each mirrors its CLI): codex uses `sandbox=`, claude/grok use `perms=`, agy uses `mode=`. Don't map `perms=` onto agy or `sandbox=` onto claude — use each skill's own keys.

## Cross-cutting safety

All four inherit the user's config (MCP/hooks/creds) and can run a full agentic loop. The shared least-privilege / verify-with-`git` / cap-the-blast-radius contract is in [`safety.md`](safety.md).
