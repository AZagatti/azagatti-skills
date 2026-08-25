# `opencode run` (headless) — full reference

`opencode run [message..]` runs [opencode](https://opencode.ai) non-interactively: it takes a prompt as positional arguments, runs a full agentic session against a provider you configured, prints the answer, and exits. It is the opencode analog of `claude -p` / `codex exec` / `grok -p` / `agy -p`. Verified against `opencode 1.18.23` on 2026-08-25 with the `zai-coding-plan` provider; re-check `opencode run --help`, `opencode models`, and `opencode agent list` because this CLI moves quickly.

## Mental model

opencode is **provider-agnostic**: one CLI in front of whatever accounts you connect, addressed as `provider/model`. That makes it the natural delegate when the second opinion should come from a model no other CLI here can reach — a z.ai GLM coding plan, for example. Three things that bite, all different from the other headless CLIs:

- **The default agent is write-enabled.** There is no "read-only unless you say otherwise" default. See below.
- **The model is `provider/model`, and the provider must be connected.** An unknown one exits 1.
- **stdout and stderr are cleanly split.** The answer alone goes to stdout.

## Permissions and agents (the #1 gotcha)

**`opencode run` writes files and runs shell commands without any approval flag.** On 1.18.23, `opencode run "Create a file called written.txt …"` created the file, and a prompt asking for `echo … > bash-proof.txt` ran the shell command. Neither run used `--auto`, and neither paused for approval.

The reason is visible in `opencode agent list`: the default `build` agent begins with

```json
{ "permission": "*", "action": "allow", "pattern": "*" }
```

Only a few narrow permissions (`doom_loop`, `external_directory` outside the allowed paths) are set to `ask`. In headless mode an `ask` cannot be answered interactively, so treat everything the agent can reach as reachable.

**The agent is the permission boundary:**

| Agent | Kind | Verified behavior |
|-------|------|-------------------|
| `build` | primary (default) | Allow-all. Wrote a file and ran `bash` unprompted. |
| `plan` | primary | Declined to create a file — "Plan mode is active, so I can't create the file yet" — returned a plan, and wrote nothing. The read-only choice. |
| `explore`, `general` | subagent | Delegated to by a primary agent, not selected directly for a task. |
| `compaction`, `summary`, `title` | primary | Internal housekeeping agents, not task agents. |

`--auto` ("auto-approve permissions that are not explicitly denied (dangerous!)") only widens what is already open. It is not the flag that enables writes, and adding it to a `build` run changes nothing you would want.

There is no `--max-turns` flag and no budget cap in `run --help`. Bound a run with the agent, the `--dir` you point it at, and a wall-clock timeout.

## Providers and credentials

`opencode auth list` prints two groups: credentials stored in `~/.local/share/opencode/auth.json`, and providers detected from environment variables (`AWS_REGION` surfaces Amazon Bedrock, for example).

A provider can also be configured in `~/.config/opencode/opencode.json`, which is where an API-key provider such as the z.ai coding plan usually lands:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "zai-coding-plan": { "options": { "apiKey": "<key>" } }
  },
  "model": "zai-coding-plan/glm-5.3",
  "small_model": "zai-coding-plan/glm-5-turbo"
}
```

`model` sets the default for a run with no `-m`; `small_model` is used for cheap internal work such as titles. **The key sits in plaintext in that file** — never copy it into a repo, a prompt, or a bug report, and keep the file out of version control.

`opencode auth list` reporting "0 credentials" does **not** mean nothing is connected; a config-file provider will not appear there. `opencode models` is the honest answer to "what can I select right now".

## Key flags

`opencode run [message..]` — the prompt is positional, so no flag-ordering trap exists. A multi-line single-quoted argument keeps its newlines, and a prompt piped on **stdin** is read the same way; both verified on 1.18.23. There is no `--prompt-file`.

| Flag | Details |
|------|---------|
| `-m, --model <provider/model>` | Model for the run. Must include the provider prefix. Unknown value → exit 1 |
| `--agent <name>` | Agent to run as. `plan` = read-only, `build` = default allow-all |
| `--dir <path>` | Directory to run in (the repo the task is about). Defaults to cwd |
| `--format <default\|json>` | `default` = formatted text, `json` = raw JSON events (JSONL) |
| `--variant <level>` | Provider-specific reasoning effort (e.g. `high`, `max`, `minimal`). Not validated |
| `-c, --continue` | Continue the last session |
| `-s, --session <id>` | Continue a specific session id |
| `--fork` | Fork the session when continuing (needs `--continue` or `--session`) |
| `-f, --file <path>` | Attach file(s) to the message (repeatable) |
| `--auto` | Auto-approve permissions not explicitly denied. Already-open surface; avoid |
| `--share` | Share the session. **Publishes it — not tested here; never use on private code** |
| `--title <text>` | Title for the session |
| `--thinking` | Show thinking blocks |
| `--attach <url>` | Attach to a running opencode server |
| `--print-logs` / `--log-level` | Diagnostics to stderr |

Related subcommands: `opencode models [provider]` (list selectable models), `opencode agent list` (agents and their permission sets), `opencode auth list` (aliased as `opencode providers`), `opencode session`, `opencode stats` (token and cost statistics), `opencode export <sessionID>`, `opencode serve` (headless server), `opencode pr <number>` (fetch and check out a GitHub PR branch, then run — **not tested in this audit**), `opencode upgrade`.

## Output shape

- **`--format default`:** stdout carries **only the final answer**. The `> build · glm-5.3` header line and every tool line (`← Write written.txt`, `→ Read note.txt`) go to **stderr**. Verified byte-for-byte: `opencode run … 2>/dev/null` emitted exactly `clean-stdout\n`. So the clean capture is simply:
  ```bash
  opencode run --agent plan "<task>" 2>/dev/null
  ```
- **`--format json`:** newline-delimited JSON events, one object per line. Observed types:

  | `type` | Carries |
  |--------|---------|
  | `step_start` | `part.snapshot`, session and message ids |
  | `text` | `part.text` — the assistant's answer |
  | `tool_use` | `part.tool` (name), `part.state.status`, `part.state.input`, `part.state.output`, `part.state.metadata.exit` |
  | `step_finish` | `part.reason` (e.g. `stop`), `part.tokens{total,input,output,reasoning,cache{read,write}}`, `part.cost` |

  Extract the answer with:
  ```bash
  opencode run --format json "<task>" 2>/dev/null | jq -r 'select(.type=="text") | .part.text'
  ```

- **There is no single terminal result object** with a success field. Use the **process exit code** as the pass/fail signal, and `git diff` for writes.
- **`cost` is provider-dependent — verify before relying on it.** It is `0` on the z.ai coding plan and on the free `opencode/*` models, while `tokens.total` stays accurate. It is populated on opencode Go: the same one-question task reported `0.00775224` on `glm-5.3`, `0.010632` on `qwen3.8-max`, `0.013972` on `grok-4.6`, and `0.0160782` on `kimi-k3` — but `0` on `ox-alpha-free`. Budget from tokens, or from `opencode stats`, unless you have checked that cost is real for the provider you are on.

## Models and variants

**Check the live model list before you trust the table below.** Run `opencode models` (or `opencode models <provider>`); the catalog is account-specific and changes without a CLI release. Listed on 2026-08-25 with `opencode 1.18.23`, which returned 130 selectable models across three providers on the audited machine: `opencode`, `amazon-bedrock`, and `zai-coding-plan`.

**opencode Go** (`opencode-go/*`, a $10/month subscription on opencode Zen — connect with `opencode auth login -p opencode-go` and an API key from https://opencode.ai/auth) exposed 23 models on 2026-08-25, including `kimi-k3`, `deepseek-v4-pro`, `grok-4.6`, `glm-5.1`/`5.2`/`5.3`, `gpt-5.6-luna`, `minimax-m3`, `qwen3.8-max`, `longcat-2.0`, and `ox-alpha-free`. Free-tier `opencode/*` models need no credentials at all — they answered with `opencode auth list` reporting 0 credentials.

The z.ai coding plan exposed:

| Model (`-m` value) | Note |
|--------------------|------|
| `zai-coding-plan/glm-5.3` | The configured default on the audited machine |
| `zai-coding-plan/glm-5.2` | |
| `zai-coding-plan/glm-5.2-highspeed` | |
| `zai-coding-plan/glm-5-turbo` | Configured as `small_model`; the cheap/fast pick |
| `zai-coding-plan/glm-4.7` | Previous generation |

Notes:

- **Always pass `provider/model`.** A bare `glm-5.3` is not a valid `-m` value.
- **A model can exist and still refuse to run.** `opencode-go/deepseek-v4-pro` exited **1** after 3s with `Error: The latest version of this model is only available hosted in China and requires explicit opt in`, plus a workspace URL to accept. The model is listed by `opencode models`; listing is not entitlement.
- **Unknown model or provider → exit 1** with a JSON blob whose `name` is `UnknownError` and whose message is the unhelpful "Unexpected server error. Check server logs for details." Both `zai-coding-plan/does-not-exist` and `nope/nope` failed this way, so read the exit code rather than the message.
- **`--variant` is not validated.** `--variant high` ran, and so did `--variant bogus-level` — exit 0, answer returned, no warning. Nothing in the output reports which variant applied, so a typo is indistinguishable from success. Take variant names from the provider's documentation.
- The same `provider/model` addressing reaches Bedrock-hosted models (`amazon-bedrock/anthropic.claude-opus-5`, `amazon-bedrock/zai.glm-5`) when that provider is connected, which is how one opencode install spans vendors.

## Sessions

`-c` continues the most recent session for that directory; `-s <sessionID>` targets one by id (session ids appear in every JSON event as `sessionID`). Continuation preserves context: a codeword stated in one run was recalled by the next `-c` run on 1.18.23. `--fork` branches instead of appending. `opencode session` and `opencode export <sessionID>` manage and dump them.

## Vision (image input)

Attach files with `-f, --file <path>` (repeatable) rather than naming a path and hoping the agent reads it. Whether an image is understood is **per-model, not a CLI feature** — pick a multimodal model when the task needs vision. Not tested in this audit.

Sources: [opencode docs](https://opencode.ai/docs/), and the live `opencode --help`, `opencode run --help`, `opencode models`, and `opencode agent list` output on 1.18.23.
