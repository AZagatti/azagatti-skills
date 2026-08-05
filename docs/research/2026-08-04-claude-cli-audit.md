# Claude Code non-interactive CLI audit

Date: 2026-08-04
Audited files: `skills/claude-headless/SKILL.md`, `skills/claude-headless/reference.md`
Installed CLI: Claude Code 2.1.220
Scope: primary sources only (installed Anthropic CLI/help and official Anthropic documentation), plus bounded live commands that did not modify this repository or invoke mutating tools.

## Executive summary

The skill's core operating model is sound: `claude -p` is an agentic, non-interactive session; its working directory is the launch directory; permission denials can coexist with `is_error: false`; JSON output and `permission_denials` must be checked; `--bare` does not use subscription OAuth; and `--resume <session_id>` is the right continuation mechanism.

Several parts are materially stale or too categorical:

1. **Model resolution is stale.** The reference says `opus` resolves to Opus 4.8 and that this account defaults to `claude-opus-4-8[1m]`. With installed 2.1.220, live calls resolved `default` to `claude-opus-5[1m]`, `opus` to `claude-opus-5`, `sonnet` to `claude-sonnet-5`, `haiku` to `claude-haiku-4-5`, and `fable` to `claude-fable-5`. Official docs now list `default`, `best`, `fable`, `opus`, `sonnet`, `haiku`, `opusplan`, and 1M forms, with resolution dependent on provider, account, organization controls, and version.
2. **Effort behavior is wrong and incomplete.** The files omit Opus 5 and the Claude Code-only `ultracode` setting. Official docs say unsupported levels on effort-capable models fall back to the highest supported level at or below the request (for example `xhigh` -> `high` on Opus 4.6), rather than being universally "silently ignored." Haiku does not support effort, but the CLI accepting `--model haiku --effort high` does not establish that the flag has an effect.
3. **"Inherits parent/config model" is misleading.** A new `claude -p` process has no guaranteed relationship to an orchestrating agent's model. Omitting `--model` follows Claude Code's own selection precedence and account/organization runtime default. On the audited Max account it selected Opus 5 with a 1M context window.
4. **Background, worktree, and resume behavior needs important caveats.** `--bg` is a supervised Claude background session managed through agent view/shell commands, not merely shell backgrounding. `-p --worktree` leaves the worktree on disk, while `-p` sessions do not appear in the interactive session picker and can only be resumed by ID from the same project/repository scope.
5. **The "all flags" reference is not complete.** Current official docs and/or installed help include material options missing from the reference, including `best`, `ultracode`, `--advisor`, system-prompt file flags, setup/maintenance flags, `--brief`, `--file`, `--prompt-suggestions`, and newer stream metadata/error events. The official CLI reference explicitly warns that `claude --help` itself is not exhaustive.

## Evidence and findings

### 1. Installed version and help surface

Commands:

```sh
command -v claude
claude --version
claude --help
claude agents --help
```

Excerpt:

```text
/Users/andrezagatti/.local/bin/claude
2.1.220 (Claude Code)

Claude Code - starts an interactive session by default, use -p/--print for
non-interactive output

-p, --print     Print response and exit ...
--effort        low, medium, high, xhigh, max
--output-format text, json, stream-json
--permission-mode acceptEdits, auto, bypassPermissions, manual, dontAsk, plan
--bg, --background ... (manage with `claude agents`)
-w, --worktree [name]
```

The reference's "Verified against `claude 2.1.208`" is stale. Its primary flag names still exist, but the installed help has additions such as `--brief`, `--file`, `--prompt-suggestions`, `--forward-subagent-text`, `--exclude-dynamic-system-prompt-sections`, and plugin URL support. Conversely, the official CLI reference says help intentionally omits some flags, so auditing only `--help` is insufficient. [Official CLI reference](https://code.claude.com/docs/en/cli-usage)

**Recommended edit:** update the verification version/date, rename "All flags" to "Common flags," link the official CLI reference, and avoid promising exhaustiveness.

### 2. Terminology and execution model

Anthropic's current term is **non-interactive mode**; "headless mode" is the former name. `-p`/`--print` executes a single prompt and exits, using the same tools, agent loop, and context management as the Agent SDK. [Official programmatic-use docs](https://code.claude.com/docs/en/headless), [official glossary](https://code.claude.com/docs/en/glossary)

The audited skill's "full agent, not a completion" description is accurate. The launch working directory claim is also consistent with the CLI: there is still no `-C` flag in installed help, and `--add-dir` grants access to additional directories.

**Recommended edit:** retain "headless" for searchability but introduce it as "non-interactive mode (formerly headless)."

### 3. Models, aliases, account-visible behavior, and defaults

The authenticated account was logged in through first-party subscription OAuth on a Max plan. No credential or email is reproduced here.

Bounded alias probe:

```sh
claude -p --safe-mode --no-session-persistence --tools "" \
  --output-format json --max-budget-usd 0.15 [--model ALIAS] \
  "Reply with exactly: OK"
```

Selected output fields:

| Requested | Live canonical model | Context reported |
|---|---|---:|
| omitted (`default`) | `claude-opus-5` (`claude-opus-5[1m]` usage key) | 1,000,000 |
| `opus` | `claude-opus-5` | 1,000,000 |
| `sonnet` | `claude-sonnet-5` | 1,000,000 |
| `haiku` | `claude-haiku-4-5` | 200,000 |
| `fable` | `claude-fable-5` | 1,000,000 |

Concise raw excerpts:

```json
{"requested":"default","is_error":false,"result":"OK","modelUsage":{"claude-opus-5[1m]":{"canonicalModel":"claude-opus-5","contextWindow":1000000}}}
{"requested":"opus","is_error":false,"result":"OK","modelUsage":{"claude-opus-5":{"canonicalModel":"claude-opus-5","contextWindow":1000000}}}
{"requested":"sonnet","is_error":false,"result":"OK","modelUsage":{"claude-sonnet-5":{"canonicalModel":"claude-sonnet-5","contextWindow":1000000}}}
{"requested":"haiku","is_error":false,"result":"OK","modelUsage":{"claude-haiku-4-5-20251001":{"canonicalModel":"claude-haiku-4-5","contextWindow":200000}}}
{"requested":"fable","is_error":false,"result":"OK","modelUsage":{"claude-fable-5":{"canonicalModel":"claude-fable-5","contextWindow":1000000}}}
```

Small Haiku usage also appeared in several non-Haiku runs for Claude Code background functionality; therefore scripts should not assume `modelUsage` contains only the requested primary model.

Current official aliases include:

- `default`: runtime/account or organization default, not a model family alias;
- `best`: Fable 5 when the organization has access, otherwise latest Opus;
- `fable`, `opus`, `sonnet`, `haiku`;
- `opusplan`, plus applicable `[1m]` forms.

On the Anthropic API, `opus` and `sonnet` currently resolve to Opus 5 and Sonnet 5. Aliases update over time and can be affected by provider and allowlists. Fable is not the default and may not be available to every organization. [Official model configuration](https://code.claude.com/docs/en/model-config)

Official account defaults currently say Max, Team Premium, Enterprise pay-as-you-go, and Anthropic API default to Opus 5; Pro, Team Standard, and Enterprise subscription seats default to Sonnet 5; organization defaults and managed restrictions can override that result. [Official model configuration](https://code.claude.com/docs/en/model-config#default-model-behavior)

**Incorrect/stale claims:**

- `opus` -> `claude-opus-4-8` (stale; live is Opus 5 on this first-party account).
- "here `claude-opus-4-8[1m]`" (stale; live default is Opus 5 with 1M).
- "No model -> inherits parent/config model" (too vague and "parent" is unjustified).
- Alias list omits `default`, `best`, and `opusplan`.

**Recommended edit:** explain selection precedence rather than pinning alias mappings in the skill. Keep a dated, provider-qualified snapshot only in the reference. Say that callers needing reproducibility must pass a full ID and must still account for organization/provider restrictions.

### 4. Effort

Installed help accepts `low`, `medium`, `high`, `xhigh`, and `max`. The official CLI reference additionally documents `ultracode`, a Claude Code orchestration setting that starts at `xhigh`; it requires 2.1.203 or later and is not a raw model effort level. [Official CLI reference](https://code.claude.com/docs/en/cli-usage), [official model configuration](https://code.claude.com/docs/en/model-config#adjust-effort-level)

Current official support table:

| Models | Supported levels |
|---|---|
| Fable 5; Opus 5; Sonnet 5; Opus 4.8; Opus 4.7 | low, medium, high, xhigh, max |
| Opus 4.6; Sonnet 4.6 | low, medium, high, max |
| Models not listed (including Haiku 4.5) | no effort support documented |

Official Claude Code behavior is: when an effort-capable model does not support the requested level, the CLI falls back to the highest supported level at or below it; organization caps may also clamp it. JSON and stream-JSON modes can apply organization clamps silently. Current model defaults are `high`, except Opus 4.7 defaults to `xhigh`. [Official model configuration](https://code.claude.com/docs/en/model-config#adjust-effort-level)

The live CLI accepted `--model haiku --effort high` and completed on Haiku, but the JSON does not report an applied effort. That proves only that the CLI does not reject this invocation; it does **not** prove the flag changes Haiku behavior.

**Incorrect/stale claims:**

- Opus 5 is missing from the table.
- "Unsupported model+effort is silently ignored" is too broad and conflicts with documented fallback/clamping for effort-capable models.
- The reference presents an API-level matrix as authoritative for CLI behavior without linking a primary source.
- Guidance favoring `xhigh` as a general default is stale for Opus 5; official default is `high`.

**Recommended edit:** replace the bespoke matrix with the official, dated support table; explicitly distinguish unsupported models from unsupported levels; add `ultracode` only as an advanced Claude Code mode; and advise measuring cost/quality rather than calling an unsupported setting harmless.

### 5. Permissions and silent denials

Official permission modes presently include `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, and `bypassPermissions`. `default` permits reads without asking; `acceptEdits` also permits file edits and common filesystem commands; `dontAsk` denies anything not pre-approved; and `bypassPermissions` skips the permission layer. `--dangerously-skip-permissions` is equivalent to `bypassPermissions`. [Official permission-mode docs](https://code.claude.com/docs/en/permission-modes)

The distinction in the audited files between `--tools` (tool availability) and `--allowedTools`/`--disallowedTools` (permission rules) is correct and important.

Read-only denial test (the requested Bash command only printed text and was never executed):

```sh
claude -p --safe-mode --no-session-persistence --tools Bash \
  --output-format json --max-budget-usd 0.08 \
  "You must use Bash to run exactly: python3 -c 'print(\"AUDIT_OK\")'. Then report what it printed."
```

Default-mode excerpt:

```json
{
  "subtype":"success",
  "is_error":false,
  "permission_denials":[{"tool_name":"Bash","tool_input":{"command":"python3 -c 'print(\"AUDIT_OK\")'"}}],
  "result":"The command needs your approval to run ... nothing executed yet."
}
```

The same probe under `--permission-mode dontAsk` also returned `subtype: "success"`, `is_error: false`, and a Bash entry in `permission_denials`. This directly confirms the skill's key warning: exit/success prose and `is_error` are insufficient when tools matter.

Nuance missing from the table: default/dontAsk can execute recognized read-only Bash commands, while prompt-class commands are denied non-interactively unless a rule pre-approves them. `acceptEdits` also auto-approves common filesystem commands such as `mkdir`, `touch`, `mv`, and `cp`, not only Edit/Write tools. [Official programmatic-use docs](https://code.claude.com/docs/en/headless#auto-approve-tools), [official permissions docs](https://code.claude.com/docs/en/permissions)

**Recommended edit:** keep the JSON verification rule, but describe permission modes as baselines plus allow/deny rules. Replace "default (read tools only)" with "reads and recognized read-only commands; anything that would prompt is denied in non-interactive mode." Make clear that the dangerous flag and `bypassPermissions` are equivalent in effect, while `--allow-dangerously-skip-permissions` merely makes bypass selectable.

### 6. Output formats and JSON shape

The `text`, `json`, and newline-delimited `stream-json` descriptions are accurate. A live stream began with `system/init` and ended with `result`:

```json
{"type":"system","subtype":"init","tools":[],"permissionMode":"default"}
{"type":"result","subtype":"success","is_error":false,"result":"OK","permission_denials":[]}
```

Official docs say `system/init` carries model/tool/MCP/plugin metadata, while the final stream line carries result, cost, and session metadata. They also document `system/api_retry`, plugin install events, hook events, and MCP/plugin startup errors that callers may need to gate on. [Official programmatic-use docs](https://code.claude.com/docs/en/headless#stream-responses)

Structured-output probe:

```sh
claude -p --safe-mode --no-session-persistence --tools "" \
  --output-format json \
  --json-schema '{"type":"object","properties":{"answer":{"type":"string"}},"required":["answer"],"additionalProperties":false}' \
  "Return answer OK"
```

Excerpt:

```json
{
  "is_error":false,
  "result":"{\"answer\":\"OK\"}",
  "structured_output":{"answer":"OK"},
  "permission_denials":[]
}
```

**Missing claim:** when `--json-schema` is used, scripts should read `.structured_output`; `.result` is still a serialized string. Current official docs also say invalid schemas exit with an error rather than silently falling back. [Official structured-output docs](https://code.claude.com/docs/en/headless#get-structured-output)

**Recommended edit:** add `structured_output`, plugin/MCP load error fields, and `system/api_retry` to the reference; recommend gating on process exit, `is_error`, permission denials, and relevant init errors according to the workflow.

### 7. Bare mode and safe mode

Installed help defines `--bare` as minimal mode that skips hooks, LSP, plugin sync, attribution, auto-memory, background prefetches, keychain reads, and CLAUDE.md auto-discovery; it sets `CLAUDE_CODE_SIMPLE=1`. Skills still resolve when explicitly invoked, and built-in Bash/read/edit tools remain available unless restricted.

Live OAuth-only bare probe:

```sh
claude -p --bare --no-session-persistence --tools "" \
  --output-format json --max-budget-usd 0.01 "Reply OK"
```

Excerpt and exit:

```text
exit 1
{"is_error":true,"terminal_reason":"api_error","result":"Not logged in · Please run /login","total_cost_usd":0,"permission_denials":[]}
```

This confirms that `--bare` does not read the account's subscription OAuth. Official docs require `ANTHROPIC_API_KEY` or an `apiKeyHelper` passed through `--settings` for first-party bare runs; Bedrock, Google Cloud's Agent Platform, and Foundry use their own credentials. `CLAUDE_CODE_OAUTH_TOKEN` is also not read in bare mode. [Official bare-mode docs](https://code.claude.com/docs/en/headless#start-faster-with-bare-mode), [official authentication docs](https://code.claude.com/docs/en/iam)

`--safe-mode` is different: it disables customizations (CLAUDE.md, skills, plugins, hooks, MCP, custom commands/agents, output styles, workflows, themes, and more) but retains auth, built-in tools, model selection, and permissions. The probes above used safe mode successfully with subscription OAuth.

**Potentially misleading claim:** "context-free" is colloquial and can imply no tools/system behavior. Bare mode still has built-in tools and a system prompt; it is reproducibility-oriented, not an empty model call.

**Recommended edit:** distinguish bare and safe mode explicitly. Change "context-free" to "without auto-discovered user/project customizations," mention explicit skill resolution and built-in tools, and retain the API-key warning.

### 8. Background execution

Installed CLI exposes `--bg`/`--background`, and `claude agents --help` exposes a scriptable `--json` view. The bounded read-only check:

```sh
claude agents --json --cwd /Users/andrezagatti/Projects/headless-delegate
```

returned `[]`, confirming no active background sessions in the audited directory. No session was dispatched because doing so would persist supervisor/session state.

Official behavior: `claude --bg` starts a supervised background session and prints a short ID. Sessions are managed with `claude agents`, `claude attach`, `claude logs`, `claude stop`, `claude respawn`, and `claude rm`; `claude agents --json` is the non-TTY listing interface. [Official agent-view docs](https://code.claude.com/docs/en/agent-view#manage-sessions-from-the-shell)

Separately, within a foreground `claude -p` run, background Bash processes receive a short grace period, while background subagents/workflows are awaited because their result contributes to final output; since 2.1.182 that subagent wait is capped at ten minutes by default. [Official programmatic-use docs](https://code.claude.com/docs/en/headless)

**Missing/ambiguous claim:** "run it in the background" could mean shell `&`, Claude's `--bg`, or an internal background tool. These have different output, lifecycle, and persistence behavior.

**Recommended edit:** name the intended mechanism. For a driver that must capture one JSON result, keep the subprocess attached with a generous bounded timeout. Use `--bg` only when the caller is prepared to manage a supervised session by ID.

### 9. Worktrees

No live worktree was created because `--worktree` mutates git/worktree state. Official behavior is sufficiently explicit:

- `--worktree [name]` creates `<repo>/.claude/worktrees/<name>/` and branch `worktree-<name>`; without a name it generates one.
- A non-interactive `-p --worktree` run skips the interactive trust check.
- Non-interactive worktrees are **not automatically cleaned up** because no exit prompt exists.
- Worktrees share the repository's `.git` storage, project plugins, and saved permission approvals; they are isolation for files, not a security sandbox.
- Default "fresh" worktrees generally branch from updated `origin/HEAD`, with documented fallbacks; `worktree.baseRef: "head"` uses local HEAD.

[Official worktree docs](https://code.claude.com/docs/en/worktrees)

**Missing claim:** the one-line "fresh git worktree" entry hides lifecycle and isolation limits.

**Recommended edit:** add location/branch, base-ref behavior, non-interactive cleanup responsibility, and the fact that `.git` and approvals are shared. Do not present worktrees as a permission or network sandbox.

### 10. Sessions, resume, and persistence

The reference correctly says JSON's `session_id` can be passed to `--resume` and that `--continue` selects the most recent session for the current directory.

Important missing constraints from official docs:

- `claude -p`/Agent SDK sessions do not appear in the interactive session picker.
- They remain resumable by explicit session ID if persistence was enabled.
- Resume lookup by ID is scoped to the project directory and its git worktrees; run the resume from that scope.
- `--no-session-persistence` suppresses transcript writes, so the emitted `session_id` cannot be used to resume.
- Resumption restores history and normally the prior model, but flags such as `--mcp-config`, `--settings`, `--plugin-dir`, `--fallback-model`, and `--add-dir` need to be passed again.
- `--fork-session` creates a new session ID instead of appending to the original transcript.

[Official session docs](https://code.claude.com/docs/en/sessions)

**Recommended edit:** add the project-scope/persistence caveat immediately beside the resume recipe, and recommend `--no-session-persistence` for one-shot automation that does not need continuation.

### 11. Cost and boundedness

`--max-budget-usd` remains the installed print-mode cost cap. The installed help still has no `--max-turns`. The reference's fixed observation of `$0.05-0.09` for a trivial call is environment/model/version-specific and already differs from these probes (for example, the Opus 5 safe-mode one-word run reported about `$0.03`; Sonnet and Haiku were lower). Model background functionality can add a second model entry to `modelUsage`.

Official docs recommend `--bare` for reproducible scripted calls, but bare requires non-OAuth auth. JSON includes `total_cost_usd` and per-model usage/cost. [Official programmatic-use docs](https://code.claude.com/docs/en/headless)

**Recommended edit:** remove the fixed observed price range or label it with date/model/account context. Retain the budget cap and recommend evaluating `.total_cost_usd` plus every `.modelUsage` entry.

## Recommended edit checklist by file

### `skills/claude-headless/SKILL.md`

1. Introduce `-p` as non-interactive mode (formerly headless).
2. Expand accepted aliases to `default`, `best`, `fable`, `opus`, `sonnet`, `haiku`, and `opusplan`, while warning that provider/account/organization rules control resolution.
3. Replace "inherits parent/config model" with Claude Code model-selection precedence; never imply it inherits the orchestrator's model.
4. Add `ultracode` only if the invocation grammar intentionally supports it; otherwise explicitly say the skill accepts the five raw levels even though the CLI has an additional orchestration mode.
5. Refine permission wording: baseline mode plus allow/deny rules; recognized read-only commands may execute; `acceptEdits` includes common filesystem operations.
6. Distinguish shell-attached long runs from Claude `--bg` supervised sessions.
7. Explain `.structured_output` for schema-constrained output.
8. Clarify bare versus safe mode and recommend `--no-session-persistence` for disposable one-shots.
9. Add resume's persistence/project-scope constraints.

### `skills/claude-headless/reference.md`

1. Update version/date and stop calling the table exhaustive.
2. Replace all pinned current alias/default mappings with provider-qualified, dated mappings; add Opus 5 and `best`/`default`/`opusplan`.
3. Replace the effort matrix and silent-ignore claim with the current official table and fallback/clamping semantics; add `ultracode` as a separate Claude Code feature.
4. Add structured-output, stream init/error/retry fields, and exit-code guidance.
5. Add bare/safe differences and explicit auth behavior.
6. Expand background, worktree, and resume lifecycle caveats.
7. Remove or date the fixed per-call cost observation.
8. Link each volatile section directly to the owning Anthropic documentation rather than another local skill's catalog.

## Uncertainty and untested areas

- Model alias and account defaults are deliberately dynamic. The live results above are exact for Claude Code 2.1.220, the audited first-party Max account, and 2026-08-04; they are not universal pins.
- Organization-managed defaults, model allowlists, effort caps, third-party providers, gateways, and zero-data-retention configurations were not available to exercise. Their behavior is reported from official docs.
- `--bg` dispatch was not run because it would create persistent supervisor/session state. Only its help/listing interface was checked live.
- `--worktree` was not run because it creates a branch and worktree. Lifecycle findings come from official docs.
- Resume/fork was not run because it requires a persistent transcript. The `--no-session-persistence` probes intentionally avoided this state.
- No file-edit, write, network-capable Bash, bypass-permissions, auto-mode, or dangerous-skip probe was executed. The permission-denial test requested a side-effect-free print command, which was denied before execution.
- The CLI accepted effort on Haiku, but no output field exposed an applied effort. No behavioral conclusion is drawn beyond successful argument parsing.

## Primary sources

- [Claude Code CLI reference](https://code.claude.com/docs/en/cli-usage)
- [Run Claude Code programmatically](https://code.claude.com/docs/en/headless)
- [Claude Code model configuration](https://code.claude.com/docs/en/model-config)
- [Claude Platform effort documentation](https://platform.claude.com/docs/en/build-with-claude/effort)
- [Claude Code permission modes](https://code.claude.com/docs/en/permission-modes)
- [Claude Code permissions](https://code.claude.com/docs/en/permissions)
- [Claude Code authentication](https://code.claude.com/docs/en/iam)
- [Claude Code agent view/background sessions](https://code.claude.com/docs/en/agent-view)
- [Claude Code worktrees](https://code.claude.com/docs/en/worktrees)
- [Claude Code sessions](https://code.claude.com/docs/en/sessions)
- Installed `claude` 2.1.220: `--version`, `--help`, `agents --help`, `auth status`, and the bounded probes recorded above.
