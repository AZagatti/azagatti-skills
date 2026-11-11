---
name: omp-print
description: "Drive omp non-interactively with `omp -p` (print mode), a headless coding agent over whatever provider `omp models` lists. Use when the user mentions omp or omp -p, wants an omp headless reviewer or delegate, or invokes `/omp-print [model=<provider/model>] [dir=<path>] <task>`."
---

# omp-print

Run **omp** non-interactively with `omp -p` (`--print`). It is a full agent over a provider from `omp models`, the same shape of delegate as `opencode-run`, with a different permission switch. Verified on `omp 18.18.7` on 2026-11-11.

## Mental model (read this first)

- **Default `omp -p` writes files and runs bash without asking.** On 18.18.7 a prompt that said to create `wrote.txt` and run `printf SHELLRAN > shell-proof.txt` did both, exit 0, with no `--auto-approve`. The same happened with extensions left on. `--auto-approve` and `--approval-mode yolo` also wrote. They are not the switch that unlocks writes.
- **There is no bash allowlist.** `omp --help` has `--tools` as a comma-separated enable list and no per-command filter. An invented `--bash-allowlist` exited 2, `unknown flag`. `--tools read,grep,bash` created both files through the shell. The read-only combination is `--tools read,grep,glob` (bash omitted). `--approval-mode always-ask` also blocked write and bash, exit 0, and did not hang. Neither combination can run `git diff`.
- **`--no-extensions` is not `--no-mcp`.** Two extension files inject into a default json run, and `--no-tools` did not stop an MCP tool. With `--no-extensions`, a json ping had no custom-role messages. The MCP servers in mcp.json still ran: `--no-extensions --no-tools` called an MCP tool. `--no-ui` exits 1 unless `--mode` is `rpc` or `rpc-ui`.

## Quick reference

| Need | Where |
| ---- | ----- |
| Permissions, the read-only lever | [reference.md → Permissions](reference.md#permissions) |
| stdout, stderr, json, tokens, cost | [reference.md → Output shape](reference.md#output-shape) |
| Positional, `@file`, stdin, system prompt | [reference.md → Prompt input](reference.md#prompt-input) |
| `--cwd`, context files, resume | [reference.md → Context](reference.md#context-cwd-and-sessions) |
| `--max-time`, `--max-cost`, exit codes | [reference.md → Limits](reference.md#limits-and-exit-codes) |
| Extensions and MCP | [reference.md → Extensions](reference.md#extensions-and-mcp) |
| Models | [reference.md → Models](reference.md#models) |

## 1. Parse the invocation

Called with a free-form task, optionally prefixed by `key=value` options:

```
/omp-print summarize this module
/omp-print model=opencode-go/deepseek-v4.1-flash dir=../repo explain this test
/omp-print readonly=1 dir=../repo review the diff
```

- **Options are only the contiguous leading tokens whose key is `model`, `dir`, or `readonly`.** Stop at the first other token. The rest is the task, verbatim.
- `model=<provider/model>` → `--model`. No `model=` → omit it and let omp's default apply. `omp models` is the source of truth. The ids below are this install on 2026-11-11, not a catalog.
- `dir=<path>` → `--cwd <path>`. Default: the launch directory. `--cwd` is where `read` and `bash` run.
- `readonly=1` → the read-only lever in the table below. Absent → the caller is asking for the CLI default, which writes. Do not take that path unless the user asked for edits and the directory is one they authorized.

## 2. Pre-flight

- Resolve every path the task names against `dir`. If one is missing, stop and ask.
- Confirm the model: `omp models`.
- For a review, pass the diff in the prompt. The read-only lever cannot run `git diff` or `gh`.
- Pass `--no-extensions` on every delegated run. It stops the extension files. It does not stop MCP servers. There is no `--no-mcp` in `omp --help` on 18.18.7.
- Pass `--no-session` unless you intend to `--continue` or `--resume`.

## 3. Build the command

| Task | Command |
| ---- | ------- |
| review / Q&A, must not write | `omp -p --cwd <dir> --model <id> --no-extensions --no-skills --no-session --tools read,grep,glob --approval-mode always-ask "<task>"` |
| edit or run tests, user asked | `omp -p --cwd <dir> --model <id> --no-extensions --no-session "<task>"` |
| script against events | add `--mode json` |

- **`--tools read,grep,glob` is the verified read-only lever.** A prompt that demanded `wrote.txt`, a shell redirect, a file read, and `git rev-parse` wrote nothing, returned the file contents, and did not run git. `--approval-mode always-ask` did the same and exited 0 (the refusal is "requires approval but no interactive UI", not a hang).
- **`--tools read,grep,bash` is not read-only.** The shell created `wrote.txt` and `shell-proof.txt`.
- **`--approval-mode write` allows the write tool and blocks bash.** `wrote.txt` was created. `shell-proof.txt` was not.
- **`--no-tools` blocks read, write, and bash.** It does not block MCP.
- Quote a prompt that contains `"`, backticks, or `$`. A multi-line single-quoted positional keeps its newlines.
- `--max-time` is the cap. Text mode with `--max-time 1s` exited 0 and printed no answer. Treat empty stdout as a failed run.

## 4. Run and capture

Text mode, answer only:

```bash
omp -p --cwd <dir> --no-extensions --no-session --tools read,grep,glob --approval-mode always-ask "<task>" 2>/dev/null
```

On 18.18.7 with `--no-extensions`, text stdout was the answer (`PING\n`) and stderr was `Working...\n`. With extensions left on, stderr also had one extension's stderr line.

Json mode. Events are one JSON object per line on stdout. stderr was empty with `--no-extensions`.

```bash
omp -p --mode json --cwd <dir> --no-extensions --no-session --tools read,grep,glob --approval-mode always-ask "<task>" \
  | jq -rs '[.[] | select(.type=="message_end" and .message.role=="assistant")] | last | .message.content[] | select(.type=="text") | .text'
```

Tokens and cost are on that assistant `message_end`, at `.message.usage` (`input`, `output`, `cacheRead`, `cacheWrite`, `totalTokens`, `reasoningTokens`, `cost.total`). Sum the assistant `message_end` events on a multi-turn run. Whether `cost.total` is a charge is untested. The CLI reports it as USD.

**Verify writes with `git status` and `git diff`, not with the model's prose.** A run that says it created a file is not evidence. A run that says it did not is not evidence either.

## 5. After it runs

- Attribute the result to the model (`deepseek-v4.1-flash via omp`), not to "omp".
- Edits: exit 0 and a diff that matches the ask. Prose does not count.
- Resume only a run that omitted `--no-session`. `--continue` and `--resume <id>` both recalled a codeword when `--session-dir` was set to a directory you own. The session id is the json `session` event's `id`.

## Failure notes

- Exit 1, stderr `Model "…" not found`: bad `--model`. Run `omp models`.
- Exit 2, `unknown flag` or `Invalid --max-cost`: the flag is wrong. `--max-cost 0` is invalid. It wants a positive USD amount.
- Exit 3, notice `Cost cap reached`: `--max-cost` blocked the next model request. In-flight tools can finish first.
- Exit 0 and empty stdout on a short `--max-time`: the cap won and text mode still returned 0. Json mode under the same cap returned exit 1, `stopReason` `aborted`, `errorMessage` `Deadline exceeded`.
- An unwanted file means the default tool set ran. Re-run with the read-only lever.
- Follow the shared blast-radius rules in [safety.md](../../docs/safety.md).
- Flags, event shapes, and the review run are in [reference.md](reference.md).
