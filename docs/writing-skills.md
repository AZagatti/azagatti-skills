# Writing skills — house style

The principles we follow when authoring or editing a skill in this repo. Distilled from Matt Pocock's [**writing-great-skills**](https://github.com/mattpocock/skills/blob/main/skills/productivity/writing-great-skills/SKILL.md) (read it in full — it's the authority) and adapted to how *these* headless-CLI skills work.

## The root virtue: predictability

A skill exists to wrangle determinism out of a stochastic agent. The goal is that the agent takes the **same process every run** — not the same output. Every rule below serves that.

## Invocation

- Our skills are **model-invoked** — they keep a `description` so the agent (or the `headless-delegate` router) can fire them autonomously. That costs **context load** (the description sits in the window every turn), so the description earns hard pruning.
- When user-invoked skills pile up past what you can remember, a **router skill** cures it: one skill that names the others and when to reach for each. **`headless-delegate` is our router.**

## The description = triggers, not identity

A description does two jobs: say what the skill is, and list the **branches** that should trigger it.

- **Front-load the leading word** (`codex`, `grok`, delegate…) — that's where invocation work happens.
- **One trigger per branch.** Synonyms that rename one branch are duplication — collapse them.
- **Cut identity that's already in the body.** Keep it to triggers + any "when another skill needs…" clause. Aim well under ~500 chars.

## Information hierarchy (progressive disclosure)

Rank material by how immediately the agent needs it, and push it down the ladder:

1. **In-skill step** — ordered actions in `SKILL.md` (our house pattern: Mental model → Quick ref → Parse → Pre-flight → Command → Run → After → Failure). Each step ends on a **checkable completion criterion** ("verify with `git diff`", "assert `permission_denials` is empty") — a vague criterion invites premature completion.
2. **In-skill reference** — rules/facts consulted on demand, still in `SKILL.md`.
3. **External reference** — detail pushed into `reference.md` behind a context pointer, loaded only when needed.

That split — a lean `SKILL.md` pointing at a fuller `reference.md` — is the pattern every skill here uses. **Co-locate**: keep a concept's definition, rules, and caveats under one heading.

## Leading words

A leading word is a compact concept already in the model's priors that anchors a behaviour in the fewest tokens. Ours: **silent no-op**, **`Cancelled`**, **hang-to-timeout**, **cross-vendor quorum**, **least privilege**. Reuse them across the skill, the docs, and commit messages so the agent links the shared language to the behaviour. Hunt restated phrases ("fast, deterministic, low-overhead") and collapse them into one word.

## Pruning

- **Single source of truth** — each fact in one authoritative place (safety lives in `docs/safety.md`; skills link it, not re-state it).
- **Relevance** — does the line still bear on what the skill does?
- **No-op hunt, sentence by sentence** — if a sentence doesn't change behaviour versus the agent's default, delete the whole sentence. Be aggressive.

## Prompt the positive (avoid negation)

"Don't think of an elephant" names the elephant. State the target behaviour so the banned one is never spoken. Keep a prohibition only as a hard guardrail you can't phrase positively (e.g. "never `--yolo` in an untrusted dir") — and pair it with what to do instead.

## Failure modes to diagnose against

**Premature completion** (ended a step before done), **duplication** (same meaning twice), **sediment** (stale layers nobody removed), **sprawl** (too long even if every line is live — cure with the ladder), **no-op** (a line the model already obeys), **negation** (steering by prohibition).
