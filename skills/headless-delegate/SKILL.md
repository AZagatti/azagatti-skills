---
name: headless-delegate
description: "Router: pick which coding CLI to delegate to (OpenAI Codex, Claude, xAI Grok, Google Antigravity) and hand off. Use when the user wants a second opinion, a cross-vendor review, to ask or delegate to another model, an independent take from a different vendor, or asks which CLI to use."
---

# headless-delegate — pick the right CLI, then hand off

You have four headless-CLI skills. This one is the **front door**: it decides *which* to use and routes to it. It does not run anything itself — it chooses, then you follow that skill.

## Choose

```
Goal → CLI (→ skill)

Cross-vendor SECOND OPINION on a diff/design (different vendor than you're running):
  • OpenAI, deep repo / real PR review .......... codex-exec        (codex exec review --base)
  • xAI take .................................... grok-headless      (grok -p)
  • Gemini / Claude / GPT-OSS via one login ..... agy-headless      (agy -p)

Structured JSON to script against .............. claude-headless / grok-headless (single-result) or codex-exec --json (JSONL); agy = plain text
Cheap / parallel bulk work ..................... claude-headless --model haiku (or a cheap model on any)
Actually EDIT files / run tests ................ codex-exec -s workspace-write (strongest repo tooling)
Same task across many models ................... agy-headless (multi-vendor behind one login)
```

Full matrix (workspace flag, default write policy, silent-fail signal, JSON, effort, resume): **[cli-comparison.md](https://github.com/AZagatti/azagatti-skills/blob/main/docs/cli-comparison.md)**.

## Two rules that always apply

1. **Cross-vendor is the value.** Delegating a model to *itself* for a "second opinion" adds cost, not perspective. If you're running Claude, get the second opinion from Codex/Grok/Antigravity — not another Claude.
2. **Safety is shared.** Whichever you pick, follow least-privilege defaults, verify writes with `git diff` (not the model's prose), and cap turns/budget/timeout. See **[safety.md](https://github.com/AZagatti/azagatti-skills/blob/main/docs/safety.md)**.

## Hand off

Once chosen, use that CLI's skill for the exact invocation, permission model, and gotchas:

| CLI | Skill | Headline gotcha to remember |
|-----|-------|------------------------------|
| OpenAI Codex | `codex-exec` | `-C` must precede `review`; reasoning off by default |
| Claude Code | `claude-headless` | writes denied by default → check `permission_denials` |
| xAI Grok | `grok-headless` | `-p` takes the prompt as its value; review needs `--always-approve` |
| Antigravity | `agy-headless` | no cwd → `--add-dir`; hangs (not errors) on unapproved tools |

## Quorum recipe (the killer app)

For a high-stakes review, run **two different vendors** on the same diff in parallel, then merge findings and **keep only claims with file:line evidence** — a plausible finding from one vendor that the other (or a quick check) can't confirm gets dropped. That cross-vendor disagreement is what makes delegation worth the cost.
