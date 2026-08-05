# Grok Build and Antigravity CLI audit — 2026-08-04

## Scope and evidence policy

This audit compares `skills/grok-headless/{SKILL.md,reference.md}` and `skills/agy-headless/{SKILL.md,reference.md}` with the installed CLIs and first-party documentation. No existing skill/code file was edited. Live tests were read-only and bounded; no write, auto-approve, bypass-permission, update-install, or session-resume behavior was exercised.

Evidence classes are kept separate:

- **Official documentation:** xAI/SpaceXAI and Google pages linked below.
- **Installed-command evidence:** local `--help`, `models`, `changelog`, update-check, and bounded print-mode output on this machine.
- **Account/project observation:** model availability and effective permissions can vary by account, configuration, rollout, and workspace trust.

## Executive findings

Both references are stale. The Antigravity reference has the larger surface mismatch: `agy 1.1.10` now has `--effort`, JSON and stream-JSON output, JSON Schema, stable model slugs, and soft-denial in headless mode. The Grok reference is also materially wrong about current effort values, `acceptEdits`, default shell denial, JSON `stopReason`, available models, and removed flags.

High-confidence corrections:

1. **`agy` is not plain-text-only.** Version 1.1.10 supports `--output-format text|json|stream-json` and `--json-schema`.
2. **`agy` now has `--effort low|medium|high`.** Effort is no longer only encoded in a display name.
3. **Headless `agy` permission prompts no longer hang by design.** Its 1.1.3 changelog says they soft-deny; this was reproduced. JSON can still report `status:"SUCCESS"` with an empty response after denial, so status alone is insufficient verification.
4. **`--add-dir` remains necessary for `agy -p` file tasks.** Without it, the live agent reported no active workspace and the scratch directory; with it, the same direct read succeeded.
5. **Current Grok effort values are only `low|medium|high`.** The installed parser rejects other values; remove `none|minimal|xhigh|max` and the stale composer matrix.
6. **Grok JSON now returns `stopReason:"end_turn"`, not `"EndTurn"`.** Existing jq assertions would fail.
7. **Grok `acceptEdits` officially auto-approves file edits.** The skill’s claim that it does not approve writes conflicts with current xAI documentation.
8. **Grok’s blanket claim that default headless denies all shell commands is false for this current trusted-project observation.** With no loaded permission rules and `yolo=false`, both a direct file read and read-only `pwd` completed. Deterministic automation should use explicit scoped rules rather than infer all behavior from this observation.
9. **`--best-of-n` and `--check` are gone from Grok 0.2.118.** Both are rejected as unexpected arguments.
10. **Account model tables have drifted.** This Grok account exposes only `grok-4.5`; this Antigravity account exposes eleven slugged variants including Gemini 3.6 Flash.

## Installed-command evidence

### Grok Build

```text
$ grok --version
grok 0.2.118 (1e1687c1cf6a) [stable]

$ grok update --check --json
{"currentVersion":"0.2.118","latestVersion":"0.2.118","updateAvailable":false,
 "installer":"internal","channel":"stable","autoUpdate":true,"error":null}

$ grok models
You are logged in with grok.com.
Default model: grok-4.5
Available models:
  * grok-4.5 (default)
```

The model list is **account-specific**, not a universal catalog. Moreover, xAI officially documents user-configured custom models, so “only IDs printed by `grok models` work” is too absolute: it is appropriate for built-in/account models, but configured custom model keys are also selectable. See [Grok Build overview](https://docs.x.ai/build/overview).

Current help includes `--cwd`, `--prompt-file`, `--prompt-json`, `--output-format plain|json|streaming-json|streaming-messages-json`, `--include-partial-messages`, `--json-schema`, `--reasoning-effort`, permission modes, session flags, and update tooling. The ordering gotcha remains valid:

```text
$ grok -p --effort high 'Reply OK.'
error: a value is required for '--single <PROMPT>' but none was supplied

$ grok --effort invalid -p 'OK'
unknown effort level 'invalid'; use one of: high, medium, low

$ grok --best-of-n 2 --version
error: unexpected argument '--best-of-n' found

$ grok --check --version
error: unexpected argument '--check' found
```

A bounded JSON run returned:

```json
{
  "text": "OK",
  "stopReason": "end_turn",
  "sessionId": "019fcf6d-f20b-7703-8ff9-b5516b34e700",
  "requestId": "e389cf6d-75af-4cdb-819d-c5acbdf0186e",
  "usage": { "total_tokens": 16613 },
  "num_turns": 1,
  "total_cost_usd": 0.0144148
}
```

Therefore replace checks such as `.stopReason == "EndTurn"` with the current lowercase value, while documenting that other terminal reasons should be re-observed rather than guessed.

Current account/project permission observation:

```text
$ grok inspect
Project trusted: yes
Permissions: Source: (none); 0 loaded

$ # ~/.grok/config.toml
[ui]
yolo = false
```

Despite that configuration, a default-permission direct `Read` of `README.md` and a read-only Bash `pwd` both completed with `stopReason:"end_turn"`. This disproves the skill’s universal “default denies command execution” claim, but should not be generalized to dangerous commands, untrusted projects, enterprise policy, or other accounts.

Current xAI docs define Ask, Auto, and Always-approve and say `acceptEdits` auto-approves edits while shell commands can still prompt. Prefer explicit `dontAsk` plus narrowly scoped `--allow`/`--deny` rules for reproducible headless automation; reserve `--always-approve` for intentionally trusted broad autonomy. Sources: [Permissions](https://docs.x.ai/build/features/permissions), [Enterprise deployments](https://docs.x.ai/build/enterprise).

Other Grok corrections:

- `--session-id` is for a **new** conversation; current help says it must not already exist. Resume with `--resume`/`--continue`; use `--fork-session` with a new session ID when branching.
- Official headless docs describe `plain`, `json`, and `streaming-json`, `--cwd`, `--resume`, and `--continue`. They also document `--no-auto-update`, which is accepted by this binary although omitted from its visible top-level help. See [Headless & Scripting](https://docs.x.ai/build/cli/headless-scripting).
- xAI documents Grok 4.5 effort as low/medium/high, default high, with reasoning not disableable. See [Reasoning](https://docs.x.ai/developers/model-capabilities/text/reasoning) and [Grok 4.5](https://docs.x.ai/developers/grok-4-5).
- Remove the secondary `mungomash.com` link from `reference.md`; the requested and stronger evidence is first-party xAI documentation.

### Antigravity `agy`

```text
$ agy --version
1.1.10

$ agy --help   # relevant excerpt
--add-dir          Add a directory to the workspace (repeatable)
--effort           Reasoning effort (low|medium|high)
--json-schema      Optional JSON schema string or path
--model            Model for the current CLI session
--output-format    text, json, stream-json (default text)
--print-timeout    default 5m0s
--continue / --conversation
--dangerously-skip-permissions
--disable-slash-commands
--mode             accept-edits, plan
```

The built-in first-party `agy changelog` records:

- **1.1.10:** fixed `--model`/`--effort` being ignored in headless and interactive runs.
- **1.1.8:** added `--output-format text|json|stream-json`, JSON Schema, typed stream events, tool/subagent payloads, and usage data.
- **1.1.5:** added `--effort` and stable model slugs; headless began honoring persisted permission/file/sandbox policies.
- **1.1.3:** fixed headless prompts hanging or silently auto-approving approval-required tools; they now soft-deny and print a required allow-rule notice.

Live JSON output confirms the new shape:

```json
{
  "conversation_id": "e2e90590-3d2b-430d-8367-0acba0f31e4a",
  "status": "SUCCESS",
  "response": "OK\n",
  "duration_seconds": 1.752251,
  "num_turns": 1,
  "usage": { "total_tokens": 18255 }
}
```

Permission denial was bounded and returned, rather than hanging:

```text
jetski: no output produced — a tool required the "command" permission that
headless mode cannot prompt for, so it was auto-denied. Add an allow-rule ...
{"status":"SUCCESS","response":"", ...}
```

This is especially important: a top-level `SUCCESS` does **not** prove the requested tool work occurred. Validate response/tool events and verify expected filesystem state externally for edit tasks.

The `--add-dir` headless rule is still correct and was directly reproduced:

```text
$ agy --output-format json --print-timeout 45s -p 'Use read_file ... README.md'
"response":"There is currently no active workspace set ... default fallback
directory /Users/andrezagatti/.gemini/antigravity-cli/scratch ..."

$ agy --add-dir /Users/andrezagatti/Projects/headless-delegate \
      --output-format json --print-timeout 45s -p 'Use read_file ... README.md'
"response":"# azagatti-skills\n"
```

Google’s general conversation docs say histories are scoped to the launch current working directory, while print-mode live behavior still requires `--add-dir` for file access. Document this as a **headless-specific workspace rule**, not as a universal statement that Antigravity never recognizes cwd. Sources: [Managing conversations](https://antigravity.google/docs/cli-conversations), [CLI permissions](https://www.antigravity.google/docs/cli-permissions).

Current account-specific model output:

```text
$ agy models
gemini-3.6-flash-high
gemini-3.6-flash-medium
gemini-3.6-flash-low
gemini-3.5-flash-high
gemini-3.5-flash-medium
gemini-3.5-flash-low
gemini-3.1-pro-high
gemini-3.1-pro-low
claude-sonnet-4-6
claude-opus-4-6-thinking
gpt-oss-120b-medium
```

The current preferred interface is a stable base slug plus separate effort, for example this succeeded:

```text
$ agy --model gemini-3.6-flash --effort low --output-format json -p '...'
{"status":"SUCCESS","response":"OK\n", ...}
```

An effort-suffixed slug conflicts with a different explicit effort:

```text
invalid model selection (--model "gemini-3.6-flash-high" --effort "low"):
--model gemini-3.6-flash-high conflicts with --effort=low
```

The older display string `"Gemini 3.5 Flash (High)"` still succeeded in this observation, likely as compatibility input, but `agy models` now emits slugs. Use emitted slugs/base slugs and treat display aliases as noncanonical. Google’s model page confirms the managed multi-vendor lineup but not this account’s exact availability: [Antigravity models](https://antigravity.google/docs/models?app=antigravity).

Update/session notes:

- `agy update --help` currently prints only `Usage of update:`; no read-only update-check flag is advertised. Do not automate `agy update` as a check because it may mutate the installation.
- Google documents the native background updater and `AGY_CLI_DISABLE_AUTO_UPDATE=true`; see [CLI troubleshooting](https://antigravity.google/docs/cli/troubleshooting) and [Installation & auth](https://antigravity.google/docs/cli/install).
- `-c`/`--continue` and `--conversation <UUID>` remain current and are officially documented in [Managing conversations](https://antigravity.google/docs/cli-conversations).

## Recommended file edits

### `skills/grok-headless/SKILL.md`

- Change verified version/model guidance to avoid hardcoded account tables; current observation is 0.2.118 and only `grok-4.5`.
- Limit `effort=` parsing/documentation to `low|medium|high` for the current CLI/model.
- Change JSON completion check to `.stopReason == "end_turn"`.
- Replace the default-denies-all-shell and `acceptEdits`-does-not-write claims with current documented modes and explicit scoped-rule guidance.
- Remove `--best-of-n`/`--check`; add current structured-output/session/update notes.
- Preserve the `-p` value ordering rule and `--cwd` guidance; both remain valid.

### `skills/grok-headless/reference.md`

- Update 0.2.93-era tables and output examples.
- Correct `acceptEdits`, effort enum, `stopReason`, `--session-id`, model availability/custom-model wording, and flag inventory.
- Remove the unsupported effort-budget speculation and secondary source link.

### `skills/agy-headless/SKILL.md`

- Add `effort=` parsing and `--effort low|medium|high`.
- Replace “plain text only/no JSON” with text/JSON/stream-JSON and JSON Schema.
- Replace “default hangs” with soft-denial behavior and explicit allow-rule guidance; warn that JSON `SUCCESS` may accompany empty denied work.
- Keep `--add-dir` mandatory for headless file tasks, but label the behavior print-mode-specific.
- Prefer model slugs/base slug plus effort and refresh the account-specific examples.

### `skills/agy-headless/reference.md`

- Update verified version from 1.1.2 to 1.1.10.
- Refresh flags, outputs, permission behavior, and models from `agy --help`, `agy models`, and `agy changelog`.
- Document `--disable-slash-commands`, structured streams, JSON Schema, and status-verification caveats.
- Clarify that the update subcommand has no advertised dry-run; document the official auto-update opt-out instead.

## Uncertainty and limits

- Model availability is account- and rollout-specific. The captured lists are observations, not universal guarantees.
- Effective permissions depend on trust, persisted settings, enterprise policy, tool classification, and the model’s chosen tool. No file-write behavior was tested.
- Grok’s exact denied-tool JSON terminal value was not re-tested; only successful `end_turn` is established. Do not preserve old capitalization/spelling without a current test.
- Antigravity’s general cwd-scoped conversation documentation and print-mode scratch behavior describe different layers; the report recommends preserving the empirically verified `--add-dir` rule specifically for `agy -p`.
- `agy update` was not invoked because it is mutating and exposes no documented check-only flag. Grok update state was checked safely with `grok update --check --json`.

## Primary sources

- xAI/SpaceXAI: [Grok Build overview](https://docs.x.ai/build/overview), [Headless & Scripting](https://docs.x.ai/build/cli/headless-scripting), [Permissions](https://docs.x.ai/build/features/permissions), [Enterprise deployments](https://docs.x.ai/build/enterprise), [Reasoning](https://docs.x.ai/developers/model-capabilities/text/reasoning), [Grok 4.5](https://docs.x.ai/developers/grok-4-5).
- Google: [Antigravity CLI getting started](https://antigravity.google/docs/cli-getting-started), [Managing conversations](https://antigravity.google/docs/cli-conversations), [CLI permissions](https://www.antigravity.google/docs/cli-permissions), [Models](https://antigravity.google/docs/models?app=antigravity), [Installation & auth](https://antigravity.google/docs/cli/install), [Troubleshooting](https://antigravity.google/docs/cli/troubleshooting), and the installed first-party `agy changelog`.
