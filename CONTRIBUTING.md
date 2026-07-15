# Contributing

Thanks for wanting to improve these skills. The bar here is **empirical accuracy**: every claim in a skill should be something you actually observed by running the CLI, not something you assumed.

## The rule that makes this repo trustworthy

> **Verify against the real CLI before you document it.** If you write "default denies writes" or "the model rejects `none`", you must have run the command and seen that behavior. Cite the CLI version you tested (`codex 0.144.3`, `claude 2.1.208`, `grok 0.2.93`, `agy 1.1.2`).

Model tables and account-visible model lists are **account/version-specific** — always tell the reader to run `codex/grok/agy models` (or the equivalent) as the source of truth, and mark tables as "example / this install".

## Adding a skill

1. `scripts/new-skill.sh <name> "<one-line description>"` — scaffolds `skills/<name>/SKILL.md` + `reference.md` from `template/` **and auto-registers it** in `.claude-plugin/marketplace.json`.
2. Write the skill following the house pattern (see any existing skill): **Mental model → Quick reference → Parse → Pre-flight → Command → Run → After → Failure notes**, with a concise `SKILL.md` and detail deferred to `reference.md`. Follow the principles in [`docs/writing-skills.md`](docs/writing-skills.md).
3. Run `python3 scripts/validate-skills.py` — it must pass (frontmatter, `name`==dir, anchors resolve, registered, version sync).
4. Link the shared [`docs/safety.md`](docs/safety.md) rather than re-writing safety notes.

## Frontmatter requirements

- `name` — kebab-case, **matches the directory name**.
- `description` — ≤ 1024 chars, includes an explicit "use when / triggers on" phrase so the skill routes correctly. Aim under ~500.

## Commit messages & releases

This repo uses [**Conventional Commits**](https://www.conventionalcommits.org) + [release-please](https://github.com/googleapis/release-please). Use `feat:` (minor), `fix:` (patch), `feat!:`/`BREAKING CHANGE:` (major); `docs:`/`ci:`/`chore:` don't cut a release. Merging the auto-generated release PR tags the version and publishes the GitHub Release — **don't** hand-edit versions or `CHANGELOG.md`.

## Before opening a PR

- `python3 scripts/validate-skills.py` passes.
- `shellcheck install.sh update.sh uninstall.sh scripts/*.sh` is clean.
- You tested any behavioral claim against the real CLI and noted the version.
