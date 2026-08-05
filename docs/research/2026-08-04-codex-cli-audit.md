# Codex CLI skill audit — 2026-08-04

## Scope and source standard

This report audits `skills/codex-exec/SKILL.md` and `skills/codex-exec/reference.md` without editing either file. Evidence is limited to:

- live, bounded, read-only commands against the installed Codex CLI;
- the account-visible model catalog returned by `codex debug models` and its local cache;
- official OpenAI documentation: [CLI command reference](https://learn.chatgpt.com/docs/developer-commands?surface=cli), [non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode), [models](https://learn.chatgpt.com/docs/models), and [agent approvals and security](https://learn.chatgpt.com/docs/agent-approvals-security);
- official OpenAI source, chiefly [`codex-rs/exec/src/cli.rs`](https://github.com/openai/codex/blob/main/codex-rs/exec/src/cli.rs) and [`codex-rs/exec/src/lib.rs`](https://github.com/openai/codex/blob/main/codex-rs/exec/src/lib.rs).

The audit was performed on 2026-08-04 in `America/Sao_Paulo` (some CLI timestamps are 2026-08-05 UTC).

## Executive findings

The skill has four material errors that should be corrected before relying on it for automation:

1. **Default output is not all “chatty stdout.”** Progress/human-readable events go to `stderr`; the final agent message goes to `stdout`. A live capture returned exactly `STREAM_OK\n` on stdout while the header, prompt, token line, and an inline copy of the answer were on stderr. The current wording will cause wrappers to parse or redirect the wrong stream. Official non-interactive docs describe the same split.
2. **`codex apply` does not apply the last local `codex exec` diff.** It requires a Codex cloud `TASK_ID` and applies that cloud chat's latest diff. Both installed help and the official CLI reference say so. The current post-run advice is incorrect and potentially operationally confusing.
3. **The guide conflates an unset effort with explicit `none`.** With user config ignored, the header says `reasoning effort: none`, but this means no override was selected, not necessarily “reasoning off.” Spark succeeded when effort was unset and failed when explicit `none` was sent; the model catalog gives Spark a default of `high`. Therefore “exec defaults to none, so Spark fails without the flag” is false.
4. **Read-only mode cannot be promised to inspect GitHub via `gh`.** Command network access is off by default, and non-interactive read-only uses `approval: never`; a blocked network request cannot be approved. The recommended `-s read-only` commands can inspect local files and Git history, but `gh` access needs separately enabled command networking or a different, explicitly authorized permission setup.

## Installed client and authentication

Concise live evidence:

```text
$ command -v codex
/Users/andrezagatti/.local/bin/codex

$ codex --version
codex-cli 0.145.0

$ codex login status
Logged in using ChatGPT
```

`codex doctor --json` reported:

```text
auth is configured
stored auth mode: chatgpt
model: gpt-5.6-sol
approval policy: Never
latest version: 0.146.0
newer version is available
```

Consequently, the results below are authoritative for installed CLI `0.145.0` and this ChatGPT account. They may differ after updating or with API-key authentication.

## High-confidence stale or incorrect claims

### 1. Output stream and duplication semantics

Current claim in `reference.md`:

> Default (text): chatty ... the final assistant message is at the end (and is printed twice: once inline, once as the final line).

This describes merged terminal output, not the actual stdout contract. A bounded `Open3.capture3` run produced:

```text
exit=0
STDOUT_BYTES=10
STDOUT="STREAM_OK\n"
STDERR_SELECTED:
OpenAI Codex v0.145.0
model: gpt-5.6-sol
approval: never
sandbox: read-only
reasoning effort: none
...
STREAM_OK
tokens used
```

The official [non-interactive mode documentation](https://learn.chatgpt.com/docs/non-interactive-mode#basic-usage) states that progress streams to stderr and only the final agent message is printed to stdout. `--json` instead makes stdout a JSONL event stream. `-o/--output-last-message` writes the final message to a file **and still prints it to stdout**.

Recommended edit:

- Replace “default output is chatty” with an explicit stream contract: final message on stdout; progress/header/tool events on stderr.
- Explain that a terminal or a tool that merges stderr and stdout can visually show the final answer twice.
- Say that ordinary shell redirection (`> file`) captures the final message; `-o` provides a separate explicit file while preserving stdout.

### 2. `codex apply` is cloud-task-only

Installed help:

```text
$ codex apply --help
Apply the latest diff produced by Codex agent as a `git apply` to your local working tree

Usage: codex apply [OPTIONS] <TASK_ID>
```

The official [CLI reference](https://learn.chatgpt.com/docs/developer-commands?surface=cli#cli-codex-apply) is more precise: it applies the most recent diff from a **Codex cloud chat**, requires authentication/access, and requires that chat's `TASK_ID`.

Current incorrect claims:

- “`codex apply` ... apply Codex's latest produced diff”
- “or `codex apply` to apply its last diff” after a local read-only `codex exec`

Recommended edit: remove `codex apply` from the local auxiliary workflow. If Codex returns a patch in a local exec run, inspect and apply it manually (or ask for a patch artifact); reserve `codex apply <TASK_ID>` for Codex cloud chats.

### 3. Unset reasoning effort is not explicit `none`

The current skill says:

> Reasoning is off by default in `exec` ... Exception: Spark requires an effort >= low, so it fails without the flag.

That inference is false. Bounded tests used `--ignore-user-config --ephemeral`, a read-only sandbox, and a no-tool prompt.

```text
$ codex exec --ignore-user-config --ephemeral -m gpt-5.6-sol ...
reasoning effort: none
...
OK
exit 0
```

```text
$ codex exec --ignore-user-config --ephemeral -m gpt-5.3-codex-spark ...
reasoning effort: none
...
OK
exit 0
```

But explicit `none` on Spark failed:

```text
$ codex exec ... -m gpt-5.3-codex-spark \
    -c 'model_reasoning_effort="none"' ...
Unsupported value: 'none' ... Supported values are: 'low', 'medium', 'high', and 'xhigh'.
exit 1
```

The account catalog reports `default_reasoning_level: high` for Spark. The consistent interpretation is:

- header `reasoning effort: none` = no explicit override was selected;
- the model/server may then use the model's default;
- explicit `model_reasoning_effort="none"` actually requests no reasoning and is model-dependent.

An explicit `none` succeeded on Sol. An explicit `minimal` failed on Sol. `ultra` succeeded on Sol. The current config-reference page is also incomplete for these account-specific tiers: its generic table lists only `minimal|low|medium|high|xhigh`, while the live catalog and official [Models page](https://learn.chatgpt.com/docs/models) document Max/Ultra behavior. Current-session behavior should win for this environment.

The user's actual `~/.codex/config.toml` contains:

```toml
model = "gpt-5.6-sol"
model_reasoning_effort = "high"
```

So a normal run that does not use `--ignore-user-config` is not “reasoning off” here in any case.

Recommended edits:

- Change “default is none/off” to “omit the override to use configuration/model defaults.”
- Do not infer disabled reasoning from the header's `none` label.
- Change Spark guidance to: explicit `none` is rejected, but an unset effort succeeds and uses model-default behavior; pass `low` or higher only when an explicit tier is wanted.
- Label `none` acceptance as empirical/account-specific and retest per model instead of presenting it as a universal tier.

### 4. Read-only does not imply usable `gh` network access

Current claims say read-only Codex can inspect GitHub via `gh` and recommend:

```text
codex exec -s read-only ...
```

for investigation, while also suggesting `review PR #123 (use gh to fetch it)`.

Official [agent approvals and security documentation](https://learn.chatgpt.com/docs/agent-approvals-security#network-access) says command network access is off by default. Its non-interactive combination is read-only plus `approval_policy=never`, which can only read files and never asks for approval. A live exec/review header confirmed:

```text
approval: never
sandbox: read-only
```

`codex exec` `0.145.0` also rejects an approval flag directly:

```text
$ codex exec -a never --help
error: unexpected argument '-a' found
exit 2
```

The top-level CLI documents `-a`, but it is not propagated to this installed `exec` parser. Config override (`-c approval_policy=...`) remains available, although unattended exec normally should stay `never`.

Recommended edits:

- Say read-only can inspect local files and local Git state, not “anything” and not remote GitHub by default.
- Treat live `gh` access as conditional on command-network permission and authentication; preflight both.
- Do not present literal PR fetching via `gh` as guaranteed in the default read-only recipe. Use an explicitly authorized networking profile/setup, or fetch PR data outside the sandbox and pipe it as input.

### 5. `workspace-write` has protected paths and no network by default

The current mental model says workspace-write can edit “anywhere under the workspace root.” This is too broad. Official [protected-path documentation](https://learn.chatgpt.com/docs/agent-approvals-security#protected-paths-in-writable-roots) says `.git`, `.agents`, and `.codex` are recursively read-only in the default workspace-write policy. Command network access also remains off unless enabled separately.

Recommended edit: say “ordinary workspace files are writable, subject to protected paths and configured writable roots; command networking is a separate permission.” Retain the warning that Codex may touch files beyond the one named in the prompt.

### 6. Review options are incomplete

Installed `codex exec review --help` supports:

```text
--uncommitted
--base <BRANCH>
--commit <SHA>
--title <TITLE>
PROMPT (or - for stdin)
```

The current reference omits `--commit` and `--title`. The official [CLI reference](https://learn.chatgpt.com/docs/developer-commands?surface=cli#cli-codex-review) and [CLI source](https://github.com/openai/codex/blob/main/codex-rs/exec/src/cli.rs) also specify that `--uncommitted`, `--base`, `--commit`, and custom `PROMPT` conflict with one another, and `--title` requires `--commit`.

The existing ordering warning is correct:

```text
$ codex exec review -C <repo> --help
error: unexpected argument '-C' found
exit 2

$ codex exec -C <repo> review --help
exit 0
```

A bounded live `review --commit HEAD` showed `sandbox: read-only`, ran local Git inspection, and completed without file changes. Keep “review is read-only” for observed `0.145.0`, but avoid extending that claim to a follow-up request to fix issues; fixes use normal sandbox/permissions.

Recommended edits: document `--commit`, `--title`, and mutual exclusivity. Describe remote PR review through `gh` as conditional/undocumented for `exec review`, not a built-in target equivalent to `--base`, `--commit`, or `--uncommitted`.

### 7. Resume documentation is incomplete

Installed help shows:

```text
codex exec resume [OPTIONS] [SESSION_ID] [PROMPT]
SESSION_ID: UUID or thread name
--last: newest recorded session
--all: disable cwd filtering
-i/--image: attach an image to the follow-up
```

The current guide's `resume --last` example is valid, but it omits thread names, current-working-directory filtering, `--all`, images, stdin prompt support, `--ephemeral`, JSON, schema, and last-message output options.

Recommended edit: at minimum document that `--last` is cwd-filtered unless `--all` is added, since this can resume a different task than a wrapper expects.

### 8. Hidden compatibility aliases versus visible help

Installed `codex exec --help` does not display `--full-auto` or `--experimental-json`, but both are accepted as hidden aliases when combined with `--help`. The official [CLI reference](https://learn.chatgpt.com/docs/developer-commands?surface=cli#cli-codex-exec) documents both, marks `--full-auto` deprecated, and official source defines `experimental-json` as an alias.

Recommended edit: retain them only in a “hidden/deprecated compatibility” note; do not list them as ordinary visible flags for `0.145.0`. Continue recommending `--sandbox workspace-write` and `--json`.

## Current account-visible model catalog

`codex debug models` is the preferred live inspection command; it refreshes and prints the raw catalog. On this ChatGPT-authenticated account, it returned the following visible models. The hidden `codex-auto-review` entry is included separately because it is not a normal picker choice.

| Slug | Visibility | Catalog default | Catalog-advertised efforts | `supported_in_api` cache field |
|---|---|---:|---|---:|
| `gpt-5.6-sol` | list | low | low, medium, high, xhigh, max, ultra | true |
| `gpt-5.6-terra` | list | medium | low, medium, high, xhigh, max, ultra | true |
| `gpt-5.6-luna` | list | medium | low, medium, high, xhigh, max | true |
| `gpt-5.5` | list | medium | low, medium, high, xhigh | true |
| `gpt-5.4` | list | medium | low, medium, high, xhigh | true |
| `gpt-5.4-mini` | list | medium | low, medium, high, xhigh | true |
| `gpt-5.3-codex-spark` | list | high | low, medium, high, xhigh | false |
| `codex-auto-review` | hide | medium | low, medium, high, xhigh, max | true |

Cache metadata after refresh:

```text
fetched_at: 2026-08-05T01:02:40.901480Z
client_version: 0.145.0
models: 8
```

The official [Models page](https://learn.chatgpt.com/docs/models) currently recommends Sol, Terra, and Luna and says GPT-5.4/GPT-5.4-mini retire from Codex with ChatGPT sign-in on 2026-08-31. It uses `gpt-5.6` in a CLI example, but that generic slug is **not** accepted by this installed/account combination:

```text
$ codex exec --ignore-user-config --ephemeral -m gpt-5.6 ...
warning: Model metadata for `gpt-5.6` not found.
ERROR: The 'gpt-5.6' model is not supported when using Codex with a ChatGPT account.
exit 1
```

Therefore the skill is right to avoid inventing model IDs and should prefer live catalog slugs. However, its model table should:

- be explicitly dated/account/version scoped;
- be generated from `codex debug models`, not only direct cache inspection;
- distinguish catalog-advertised efforts from empirically accepted extra values such as explicit `none`;
- label `supported_in_api` as a cache field, not as proof of public API availability or entitlement;
- note the announced GPT-5.4 retirement.

## Claims that remain correct

- `codex exec`/`codex e` is the non-interactive entry point.
- `-C` must precede the `review` subcommand in this installed parser.
- `--uncommitted` includes staged, unstaged, and untracked changes.
- `--base` reviews against a branch; `--commit` should now be added.
- `--json` emits JSONL; `--output-schema` requests schema-conforming final output.
- `--ephemeral` avoids persisting rollout/session files.
- `--ignore-user-config` bypasses `$CODEX_HOME/config.toml` while leaving auth available.
- `--skip-git-repo-check` permits use outside Git repositories.
- `--yolo`/danger-full-access remains an explicitly dangerous option.
- Unsupported ChatGPT-account model slugs produce a fallback-metadata warning followed by a 400 “not supported” error; this was reproduced with the currently documented generic `gpt-5.6` slug.
- `codex doctor` is now a valid diagnostic command, and `codex login status` is the most direct auth-status check.

## Recommended edit order

1. Fix output-stream semantics and remove local `codex apply` advice.
2. Rewrite the reasoning section around “unset/model default” versus explicit `none`; correct Spark behavior.
3. Remove the unconditional `gh`/GitHub promise from read-only mode and document network permission separately.
4. Update review/resume options and mutual-exclusion/cwd-filter rules.
5. Add protected workspace paths and clarify `exec` approval behavior (`-a` is rejected by installed `exec`; use config/`-c` where needed).
6. Refresh the model section from `codex debug models`, date it, and add the GPT-5.4 retirement note.
7. Demote hidden aliases to compatibility notes.

## Uncertainty and limits

- Model availability is account-, auth-, rollout-, and version-specific. This report records one ChatGPT account on CLI `0.145.0`; API-key authentication may differ.
- `0.146.0` was available but was not installed because upgrading was outside scope. Official docs may already describe behavior from a newer client, which likely explains some docs/help drift.
- Only Sol and Spark received explicit `none` tests; the prior table's `none` claims for Terra, Luna, GPT-5.5, GPT-5.4, and GPT-5.4-mini were not re-tested in this bounded audit.
- `ultra` was tested only on Sol. Its documented meaning (automatic subagent delegation) comes from the official Models page.
- No write sandbox was exercised. Workspace-write conclusions come from official documentation/help, not mutation tests.
- No real remote PR was fetched. The concern about `gh` is based on the official network-off sandbox contract and installed approval behavior; repository-specific MCP/connectors or custom permission profiles could provide other paths.
- A background research agent was requested by the local research workflow, but the agent pool was full; all evidence was gathered locally.
