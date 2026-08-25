# Headless CLI comparison & chooser

The five skills document five CLIs that all do "run an agent non-interactively." This page is the **cross-cutting view** — pick the right one, and translate one mental model across their different flag dialects. Every fact here is verified in the individual skills' `reference.md`; CLI versions tested: `codex 0.146.0`, `claude 2.1.220`, `grok 0.2.118`, `agy 1.1.10`, `opencode 1.18.23`.

## At a glance

| | **codex-exec** (OpenAI) | **claude-headless** (Anthropic) | **grok-headless** (xAI) | **agy-headless** (Google Antigravity) | **opencode-run** (any connected provider) |
|---|---|---|---|---|---|
| Headless command | `codex exec` | `claude -p` | `grok -p` | `agy -p` | `opencode run` |
| Prompt delivery | arg or `-` stdin | arg or stdin | **prompt is `-p`'s value** (ordering gotcha) or `--prompt-file` | prompt is `-p`'s value (aliases `--print` / `--prompt`) | positional arg |
| Workspace | `-C <dir>` | launch **cwd** (+ `--add-dir`) | `--cwd <dir>` | **none → `--add-dir` required** (else isolated scratch) | `--dir <dir>` (defaults to cwd) |
| Default write policy | read-only/configured | configured baseline; prompt-class tools deny unless pre-authorized | trust/settings/rule-dependent; approval prompts deny headlessly | denied in headless, including `--mode accept-edits` on 1.1.10 | **allow-all — writes and runs shell with no flag** |
| Silent-fail signal | command error / failed JSONL event | `permission_denials[]`, often `is_error:false` | non-`end_turn` stop reason or missing side effect | stderr denial + empty response while JSON says `status:"SUCCESS"` | unvalidated `--variant` runs anyway; no terminal result object |
| Grant writes | `-s workspace-write` | `--permission-mode acceptEdits` or scoped rules | scoped permission rule; `--always-approve` only when authorized | scoped `permissions.allow`; dangerous bypass only when authorized | already granted — **restrict** with `--agent plan` |
| Structured output | `--json` (JSONL events); `-o` = final message | `--output-format json` (`.result` / `.structured_output`) | `--output-format json` (`.text/.thought/.stopReason`) | `--output-format json` or `stream-json` | `--format json` (JSONL events); stdout alone = the answer |
| Reasoning effort | `-c model_reasoning_effort` (config/model-specific) | `--effort` (per-model) | `--reasoning-effort` (per-model) | `--effort low\|medium\|high` | `--variant` (provider-specific, **unvalidated**) |
| Session resume | `codex exec resume` | `--resume` / `--continue` | `-c` / `-r <id>` | `-c` / `--conversation <id>` | `-c` / `-s <id>` (`--fork` to branch) |
| Built-in PR review | `review --base`/`--uncommitted` | `claude ultrareview [target]` (cloud, billed/entitled) | — | — | `opencode pr <number>` (checkout + run; not audited) |
| Web search | via separately authorized tools/network | permission/config dependent | permission/config dependent | not documented | not documented |

## Which one?

```
Need a second opinion from a DIFFERENT vendor than you're running?
├── OpenAI depth on a repo / real PR review ......... codex-exec  (review --base)
├── xAI cross-vendor take on a diff ................. grok-headless
├── Gemini / Claude / GPT-OSS behind ONE login ...... agy-headless
└── A model only YOUR account reaches (z.ai GLM …) .. opencode-run  (`opencode models`)

Need structured JSON to script against? ............. claude-headless / grok-headless / agy-headless (single-result JSON), or codex-exec --json / opencode-run --format json (JSONL events)
Need cheap/parallel bulk work? ...................... /claude-headless model=haiku <task>  (or a cheap model on any)
Need it to actually EDIT files / run tests? ......... /codex-exec sandbox=workspace-write <task>  (strongest repo tooling)
Multi-model comparison from one tool? ............... agy-headless (`agy models` spans vendors) or opencode-run (any provider you connect)
Read-only review that MUST NOT write? ............... /opencode-run agent=plan <task>  (its default agent writes)
```

**The killer app is cross-vendor disagreement** — run two vendors on the same diff and merge findings (see the quorum recipe in the [`headless-delegate`](../skills/headless-delegate/SKILL.md) skill). Delegating a model to *itself* adds cost, not perspective.

When Antigravity supplies the second opinion, explicitly select an underlying vendor different from the orchestrator; its default can otherwise route back to the same vendor.

## One vocabulary, five dialects

When a skill takes `key=value` options, map this shared vocabulary to each CLI:

| Intent | codex | claude | grok | agy | opencode |
|--------|-------|--------|------|-----|----------|
| **dir** (workspace) | `-C` | cwd / `--add-dir` | `--cwd` | `--add-dir` | `--dir` |
| **model** | `-m` | `--model` | `-m` (account model id or custom-model key) | `--model <base-or-emitted-slug>` | `-m provider/model` |
| **effort** | `-c model_reasoning_effort=` | `--effort` | `--reasoning-effort` | `--effort` | `--variant` |
| **access** (let it write/run) | `-s workspace-write` | `--permission-mode acceptEdits` | scoped rule / `--always-approve` | scoped `permissions.allow` / dangerous bypass | on by default — `--agent plan` to revoke |
| **timeout / budget** | background + `-o` | `--max-budget-usd` | `--max-turns` | `--print-timeout` | none — use a shell timeout |

> ⚠️ The option **keys differ by skill** on purpose (each mirrors its CLI): codex uses `sandbox=`, claude/grok use `perms=`, agy uses `mode=`, opencode uses `agent=`. Don't map `perms=` onto agy or `sandbox=` onto claude — use each skill's own keys.

## Cross-cutting safety

All five inherit the user's config (MCP/hooks/creds) and can run a full agentic loop. The shared least-privilege / verify-with-`git` / cap-the-blast-radius contract is in [`safety.md`](safety.md).
