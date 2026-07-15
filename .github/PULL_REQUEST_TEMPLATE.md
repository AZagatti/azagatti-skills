<!-- Use a Conventional Commit style title: feat: / fix: / docs: / ci: / chore: -->

## What & why

<!-- What does this change, and why? -->

## Empirical verification

<!-- Required for any behavioral claim. Which CLI + version did you run, and what did you observe? -->
- CLI + version tested:
- Command(s) run:
- Observed behavior:

## Checklist

- [ ] `python3 scripts/validate-skills.py` passes
- [ ] `shellcheck install.sh update.sh uninstall.sh scripts/*.sh` is clean
- [ ] Behavioral claims were verified against the real CLI (version noted above)
- [ ] Model/account-specific facts point the reader to runtime discovery (`* models`) as source of truth
- [ ] New skill? Registered in `.claude-plugin/marketplace.json` and links `docs/safety.md`
