# `omp -p` (print mode), full reference

`omp -p` (`--print`) takes a prompt, runs a full agent session, prints the answer, and exits. The prompt is a positional argument. `-p` is a boolean, unlike `grok -p`, which takes the prompt as its value. Verified against `omp 18.18.7` on 2026-11-11 with `opencode-go/deepseek-v4.1-flash`, plus one run of `opencode-go/glm-5.3-flash`. Re-check `omp --help` and `omp models`. This CLI moves.

## Permissions

**Default print mode writes files and runs bash with no approval flag.** In a throwaway git repo, this prompt:

> Create `wrote.txt` containing `WROTE`. Run `printf SHELLRAN > shell-proof.txt`. Read `alpha.txt`. Run `git rev-parse --short HEAD`.

With `--no-extensions --no-session --thinking off` and no `--tools` or `--approval-mode`, exit 0 in 27s. `wrote.txt` was `WROTE`, `shell-proof.txt` was `SHELLRAN`, and `git status` showed both untracked. The same prompt with extensions left on (no `--no-extensions`) also created both files, stdout `DONE`, exit 0 in 31s.

| Flags | Wrote `wrote.txt` | Ran the shell redirect | Read `alpha.txt` | Ran git |
| --- | --- | --- | --- | --- |
| default tools, extensions off | yes | yes | yes | yes |
| default tools, extensions on | yes | yes | not asked | not asked |
| `--auto-approve` | yes | yes | yes | yes |
| `--approval-mode yolo` | yes | yes | yes | yes |
| `--approval-mode write` | yes | no, bash "requires approval but no interactive UI" | yes | no. The model read `.git/refs/heads/main` instead |
| `--approval-mode always-ask` | no | no | yes | no. Exit 0, did not hang |
| `--no-tools` | no | no | no | no |
| `--tools read,grep` | no | no | yes | no |
| `--tools read,grep,bash` | yes, via the shell. `write` was not in the list | yes | yes | yes |
| `--tools read,grep,bash --approval-mode always-ask` | no | no | yes | no |
| `--tools read,grep,bash --approval-mode write` | no | no | yes | no |

**The read-only lever is `--tools read,grep,glob` plus `--approval-mode always-ask`.** Omit `bash`. Glob was accepted on the review run and was not called. A prompt that also asks for `git diff` does not get `git diff`.

**Bash cannot be limited to an allowlist.** Help exposes `--tools` as a comma-separated enable list. `--bash-allowlist git` exited 2: `unknown flag: --bash-allowlist`. Enabling `bash` enables any command the model types, including a redirect that creates a file.

`--approval-mode` values in help: `always-ask`, `always-ask-cached`, `write`, `yolo`. `always-ask-cached` was not run. `--no-pty` was not run.

`--auto-approve` does not change a default that already writes. It is the wrong flag to reach for when you want a review.

## Output shape

**`--mode text` (the default).** With `--no-extensions --no-tools`, stdout was `PING\n` (5 bytes) and stderr was `Working...\n`. Exit 0. With extensions left on, stderr was one extension's stderr line plus `Working...`, and stdout was still `PING\n`.

**`--mode json`.** Newline-delimited JSON on stdout. With `--no-extensions --no-tools`, stderr was empty (0 bytes) and the answer was `PONG`. Event types on that run: `session`, `agent_start`, `turn_start`, `message_start`, `message_end`, `message_update`, `turn_end`, `agent_end`.

| `type` | What was in it |
| --- | --- |
| `session` | `version` 3, `id`, `timestamp`, `cwd` |
| `message_end` role `user` | `.message.content[].text` is the prompt |
| `message_update` | `.assistantMessageEvent.type` of `text_start`, `text_delta`, `text_end`. A tool run also had `thinking_*` and `toolcall_*` |
| `message_end` role `assistant` | `.message.content[]` items of `type` `text` and, on a tool turn, `thinking` and `toolCall`. `.message.stopReason` (`stop`, `toolUse`, `aborted`). `.message.usage` |
| `tool_execution_start` | `toolName`, `toolCallId`, `args` |
| `tool_execution_end` | `toolName`, `isError`, `result` |
| `tool_execution_update` | partial tool output. Seen on the bash run |
| `notice` | `level`, `source`, `message`. The cost cap used this |
| `agent_end` | `isTerminal`, `yielded`, `messages` |

Extract the final answer from the last assistant `message_end`:

```bash
jq -rs '[.[] | select(.type=="message_end" and .message.role=="assistant")] | last | .message.content[] | select(.type=="text") | .text'
```

**Tokens and cost** sit on `.message.usage` of each assistant `message_end`: `input`, `output`, `cacheRead`, `cacheWrite`, `totalTokens`, `reasoningTokens`, and `cost` with `input`, `output`, `cacheRead`, `cacheWrite`, `total`. A one-word `--no-tools` reply reported `input` 122705 and `cost.total` 0.018410838. The same shape with `--no-skills --no-context-files` was still `input` 120691. A `--tools read,grep` run that actually called the tools reported `input` 14341 on the tool turn. Sum every assistant `message_end` for a session total. Whether `cost.total` is billed is untested. The CLI labels the cap as USD (`--max-cost`).

A tool-using assistant content item of `type` `toolCall` has `name`, `id`, `arguments`. `tool_execution_start.args` for `read` was `{path}`, for `grep` `{pattern, path}`, for `bash` `{command}`.

## Prompt input

All of these were `--no-extensions --no-skills --no-tools --mode text`, and each exit was 0.

| Form | What came back |
| --- | --- |
| Positional `"Reply with exactly the single word PING"` | `PING` |
| Multi-line positional, a newline inside the argument | `LINEONE LINETWO` |
| `@/abs/path/atfile.md` as the positional, file text `Reply with exactly the single word ATFILE` | `ATFILE` |
| The prompt on stdin, no positional | `FROMSTDIN` |
| `--system-prompt /path/to/file` whose text says to reply `SYSFILE`, user says hello | `SYSFILE` |
| `--system-prompt` with that instruction as a literal string | `SYSLITERAL` |
| `--append-system-prompt /path` whose text says to end with `APPENDFILE` | `USERWORD` then `APPENDFILE` |
| `--append-system-prompt` with the literal `End your reply with the token APPENDLIT.` | `USERWORD APPENDLIT` |

A path is read for both `--system-prompt` and `--append-system-prompt`. Help text says "text or file contents" only on the append flag. Both accepted a path and a literal on 18.18.7. `--system-prompt-template` was not run.

## Context, cwd, and sessions

- **`--no-context-files`.** A directory whose `AGENTS.md` said the only correct reply was `FROMAGENT`: without the flag, stdout was `FROMAGENT`. With `--no-context-files --no-skills --no-tools`, stdout was `No word was specified in the conversation, so there is nothing to echo.`
- **`--cwd`.** Launched from the parent directory with `--cwd` set to the repo, `--tools read,bash`. Stdout was `PWD=<the repo> ALPHA=alpha-token-771`. File reads and bash both used `--cwd`, not the launch directory.
- **`--no-session`.** The json `session.id` from a `--no-session` review did not appear in the default session directory.
- **Resume.** With `--session-dir` pointed at a throwaway directory and without `--no-session`, the first run was told the codeword `PURPLE-OTTER`. A jsonl named `<timestamp>_<id>.jsonl` appeared in that directory. The id matched the `session` event. A second run with `--continue`, and a third with `--resume <id>`, each replied `PURPLE-OTTER`. `--restore` was not run.
- **`--no-rules`** is in help. It was not run.
- **`--add-dir`** was not run.

## Limits and exit codes

| Case | Exit | What was printed |
| --- | --- | --- |
| `--model opencode-go/does-not-exist` | 1 | stderr `Model "opencode-go/does-not-exist" not found` |
| `--bash-allowlist git` | 2 | `unknown flag: --bash-allowlist` |
| `--max-cost 0` | 2 | `Invalid --max-cost value: "0". Expected a positive USD amount` |
| `--max-cost 0.0000001` and a prompt that asked for two bash calls | 3 | Both bash calls finished in the first response. A `notice` said `Cost cap reached: this session spent $0.02 of its $0.0000 cap (--max-cost / session.maxCost), so the next model request was not sent.` No final `DONE` |
| `--max-time 1s`, text, `--no-tools`, one word | 0 | stdout empty, stderr `Working...`. Elapsed 2.9s |
| `--max-time 30s`, json, `--tools read,grep` | 1 | assistant `stopReason` `aborted`, `errorMessage` `Deadline exceeded`. No tool call |
| `--max-time 4m`, json, a pasted-diff review allowed to grep | 1 | same `Deadline exceeded`, partial report, no `VERDICT:` |

`--thinking off`, `--thinking low`, and `--thinking max` on a one-word reply each returned a `text` block and no `thinking` block (`reasoningTokens` absent). A bash run that passed `--thinking off` still had a `thinking` block and `reasoningTokens` 47. `--print-thoughts` and `--hide-thinking` were not run.

## Extensions and MCP

The extensions directory on this install contains two extension files. mcp.json names the MCP servers configured for this install. Print mode loads them unless a flag says otherwise.

A default `--mode json --no-tools` run (extensions on) was 783 lines. It included `message` roles `custom` for the two extension files, then 12 MCP tool calls. The final assistant text said it had created an application named `sandbox`. `--no-tools` did not stop those MCP calls. Stderr was one extension's stderr line.

The same ping with `--no-extensions` was 12 lines, roles `user` and `assistant` only, answer `PONG`, stderr empty.

`--no-extensions --no-tools` called an MCP tool (`isError` false) and then replied `PONG`. Extension discovery and MCP are different switches. Help has `--no-extensions`. It has no `--no-mcp`.

`--no-ui` with `--mode text` exited 1: `--no-ui requires --mode rpc or --mode rpc-ui`. It is not a print-mode off switch. `--mode rpc` was not run.

`PI_CODING_AGENT_DIR` pointed at an empty directory: exit 1, `No API key found for opencode-go`, and stderr still warned that an MCP server failed to connect. That env var is not a read-only switch, and it drops the provider login that lives in the normal agent dir.

The squash review below passed `--tools read,grep,glob` and called `read` four times. A pasted-diff review that was allowed to grep called `read` 16 times and `grep` 13 times, and no other tool. That is not a proof that the flag hides MCP. The probe that asked for an MCP call under `--tools read,grep` aborted at `--max-time` before any tool ran.

## Models

Run `omp models`. The table in the CLI is account-specific. On 2026-11-11, provider `opencode-go` listed `deepseek-v4.1-flash` (thinking `low,high,max`) and `glm-5.3-flash` (same). One `--no-tools` text run of `opencode-go/glm-5.3-flash` replied `GLM`, exit 0. `glm-5.3` (not flash) was not used.

`--model opencode-go/deepseek-v4.1-flash` is an exact provider/model id. A missing id exits 1 before a request.

## The read-only review

One standards review of `git diff <base>..<head>` in a private repo (11 files, 365 insertions, 18 deletions). The 11 files in that range, plus `AGENTS.md`, `CLAUDE.md`, `docs/agents/global-rules.md`, and `docs/agents/design.md`, matched the checkout that was read. The system prompt was only the `prompt` field of the standards-reviewer agent, written to a temp file and passed as `--system-prompt`. Nothing else from that config was copied.

`git status --short` was empty before the run and empty after it (0 bytes both times). Findings were not applied.

Flags: `--no-extensions --no-skills --no-context-files --no-session --tools read,grep,glob --approval-mode always-ask --thinking off --mode json --max-time 8m`, with `--cwd` set to that private repo. The diff was pasted into the prompt because this lever cannot run git. The prompt forbade grep and limited reads to those four files.

Wall time 70.25s (`/usr/bin/time` real). Exit 0. Tool calls: `read` of `AGENTS.md`, `CLAUDE.md`, `docs/agents/global-rules.md`, and `docs/agents/design.md`, each `isError` false. No `grep`, no `bash`, no MCP name. Assistant `stopReason` was `toolUse`, then `stop`. The last line of the report was `VERDICT: no must-fix`. Summed usage: `input` 20130, `output` 5809, `cacheRead` 17024, `totalTokens` 42963, `reasoningTokens` 4822, `cost.total` 0.006555972.

## Flags not run

`--mode rpc`, `--mode rpc-ui`, `--plan-yolo`, `--approval-mode always-ask-cached`, `--restore`, `--no-rules`, `--no-pty`, `--add-dir`, `--system-prompt-template`, `--print-thoughts`, `--hide-thinking`, `--share` (not in the help text that was captured), `--wait-async`. Do not describe their behavior from the help line alone.
