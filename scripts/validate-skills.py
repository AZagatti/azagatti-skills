#!/usr/bin/env python3
"""Validate every skill + the marketplace manifests. Zero third-party deps.

Checks (fail the build on any ERROR):
  - SKILL.md has YAML frontmatter with non-empty `name` and `description`.
  - `name` == directory name, is kebab-case, and matches the marketplace entry.
  - `description` <= 1024 chars (Claude Code limit) and contains a "when to use" trigger.
  - Every `reference.md#anchor` link in SKILL.md resolves to a real heading (GitHub slug rules).
  - marketplace.json / plugin.json are valid JSON; every listed skill path exists with a SKILL.md;
    plugin.json version == marketplace metadata.version.
Run: python3 scripts/validate-skills.py
"""
from __future__ import annotations
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS = ROOT / "skills"
errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def gh_slug(heading: str) -> str:
    """GitHub-Flavored-Markdown anchor slug (does NOT collapse consecutive hyphens)."""
    s = heading.strip().lower()
    s = re.sub(r"[^\w\- ]", "", s)  # drop punctuation except word chars, space, hyphen
    return s.replace(" ", "-")


def parse_frontmatter(text: str) -> dict[str, str]:
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        return {}
    fm: dict[str, str] = {}
    for line in m.group(1).splitlines():
        km = re.match(r'^(\w+):\s*(.*)$', line)
        if km:
            val = km.group(2).strip().strip('"')
            fm[km.group(1)] = val
    return fm


def load_json(path: Path):
    try:
        return json.loads(path.read_text())
    except Exception as e:  # noqa: BLE001
        err(f"{path.relative_to(ROOT)}: invalid JSON — {e}")
        return None


# --- marketplace + plugin manifests -----------------------------------------
mkt = load_json(ROOT / ".claude-plugin" / "marketplace.json")
plg = load_json(ROOT / ".claude-plugin" / "plugin.json")
registered: set[str] = set()
if mkt:
    for p in mkt.get("plugins", []):
        for s in p.get("skills", []):
            sp = (ROOT / s).resolve()
            registered.add(sp.name)
            if not (sp / "SKILL.md").exists():
                err(f"marketplace.json lists '{s}' but {s}/SKILL.md is missing")
if mkt and plg:
    mv = mkt.get("metadata", {}).get("version")
    pv = plg.get("version")
    if mv != pv:
        err(f"version mismatch: plugin.json={pv} vs marketplace metadata.version={mv}")

# --- each skill --------------------------------------------------------------
skill_dirs = sorted([d for d in SKILLS.iterdir() if d.is_dir()]) if SKILLS.exists() else []
if not skill_dirs:
    err("no skills/ directories found")

descriptions: dict[str, str] = {}
for d in skill_dirs:
    name = d.name
    sk = d / "SKILL.md"
    if not sk.exists():
        err(f"{name}: missing SKILL.md")
        continue
    text = sk.read_text()
    fm = parse_frontmatter(text)
    if not fm:
        err(f"{name}: SKILL.md has no YAML frontmatter")
        continue

    fname = fm.get("name", "")
    if not fname:
        err(f"{name}: frontmatter missing `name`")
    elif fname != name:
        err(f"{name}: frontmatter name '{fname}' != directory '{name}'")
    if fname and not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", fname):
        err(f"{name}: name '{fname}' is not kebab-case")

    desc = fm.get("description", "")
    if not desc:
        err(f"{name}: frontmatter missing `description`")
    else:
        descriptions[name] = desc.lower()
        if len(desc) > 1024:
            err(f"{name}: description is {len(desc)} chars (max 1024)")
        elif len(desc) > 700:
            warn(f"{name}: description is {len(desc)} chars — consider tightening (<~500)")
        if not re.search(r"\b(use when|triggers? on|invoke|when the user)\b", desc, re.I):
            warn(f"{name}: description has no explicit 'use when'/'triggers on' phrase")

    if name not in registered:
        err(f"{name}: not registered in marketplace.json plugins[].skills")

    # anchor resolution: SKILL.md → reference.md
    ref = d / "reference.md"
    if ref.exists():
        slugs = {gh_slug(h) for h in re.findall(r"^#{1,6}\s+(.*)$", ref.read_text(), re.M)}
        for anchor in re.findall(r"\]\(reference\.md#([a-z0-9\-]+)\)", text):
            if anchor not in slugs:
                err(f"{name}: SKILL.md links reference.md#{anchor} but no heading has that slug")

# --- near-duplicate description routing check --------------------------------
names = list(descriptions)
for i in range(len(names)):
    for j in range(i + 1, len(names)):
        a, b = set(descriptions[names[i]].split()), set(descriptions[names[j]].split())
        if a and b:
            jac = len(a & b) / len(a | b)
            if jac > 0.6:
                warn(f"descriptions of '{names[i]}' and '{names[j]}' are {jac:.0%} similar — routing may collide")

# --- report ------------------------------------------------------------------
for w in warnings:
    print(f"WARN  {w}")
for e in errors:
    print(f"ERROR {e}")
n = len(skill_dirs)
if errors:
    print(f"\n✗ {len(errors)} error(s), {len(warnings)} warning(s) across {n} skill(s)")
    sys.exit(1)
print(f"\n✓ {n} skill(s) valid, {len(warnings)} warning(s)")
