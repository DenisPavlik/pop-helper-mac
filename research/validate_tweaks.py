#!/usr/bin/env python3
"""Validates PoPHelper/Resources/tweaks.json against the pristine PoP 3.9.5 files.

Per operation it checks:
  (a) `original` occurs exactly `expectedCount` times in the pristine file
  (b) rendering `replacement` with each param's originalValue reproduces
      `original` byte-exactly (only meaningful for parameterized in-place
      operations, i.e. operations whose replacement contains placeholders;
      no-placeholder operations are full literal replacements and are instead
      required to differ from `original`)
  (c) the regex built per the schema doc (placeholders -> (-?\\d+), everything
      else re.escape'd) matches the replacement rendered with default params
  (d) every placeholder references a declared param. Brace tokens that are
      NOT declared params (e.g. game string registers like {s3}, {reg24})
      are treated as literal text — they must appear verbatim in `original`
      too, which catches typo'd placeholder keys.

It also performs basic schema sanity checks (categories, occurrence values,
bilingual names, unique ids, integer params within min/max).

Usage:
  python3 validate_tweaks.py            # validate against pristine files
  python3 validate_tweaks.py --status   # additionally report applied /
                                        # not applied / conflict against the
                                        # CURRENT mod files

Exits non-zero if any validation check fails.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(HERE, "..", "PoPHelper", "Resources", "tweaks.json")

PRISTINE_DIR = (
    "/Users/denys/Library/Application Support/Steam/steamapps/common/"
    "MountBlade Warband/Modules/Prophesy of Pendor V3.9.5/_backupHelper/"
    "Backup Your Files/[Tweaks] 26.10.23       15-03-18"
)
CURRENT_DIR = (
    "/Users/denys/Library/Application Support/Steam/steamapps/common/"
    "MountBlade Warband/Modules/Prophesy of Pendor V3.9.5"
)

CATEGORIES = {"spawns", "parties", "world", "battle", "troops", "tournaments",
              "noldor", "companions", "prisoners", "kingdom", "economy", "items",
              "quests", "cheats", "other"}
PLACEHOLDER_RE = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)\}")

failures = []


def fail(msg):
    failures.append(msg)
    print(f"  FAIL: {msg}")


def load_file(directory, name, cache={}):
    key = (directory, name)
    if key not in cache:
        with open(os.path.join(directory, name), "rb") as f:
            # ISO-Latin-1, matching the app's ModManager: 1:1 byte mapping so
            # huge non-UTF-8 module files (e.g. item_kinds1.txt) decode cleanly.
            cache[key] = f.read().decode("latin-1")
    return cache[key]


def render(template, values):
    """Substitute only declared param placeholders; leave other braces alone."""
    return PLACEHOLDER_RE.sub(
        lambda m: str(values[m.group(1)]) if m.group(1) in values else m.group(0),
        template)


def param_keys(template, declared):
    """Brace tokens in template that are declared params, in order."""
    return [k for k in PLACEHOLDER_RE.findall(template) if k in declared]


def build_regex(template, declared):
    """Schema rule: param placeholders -> (-?\\d+), everything else (including
    literal game-text registers like {s3}) re.escape'd."""
    parts, pos = [], 0
    for m in PLACEHOLDER_RE.finditer(template):
        if m.group(1) not in declared:
            continue
        parts.append(re.escape(template[pos:m.start()]))
        parts.append(r"(-?\d+)")
        pos = m.end()
    parts.append(re.escape(template[pos:]))
    return re.compile("".join(parts))


def validate(db):
    seen_ids = set()
    n_ops = 0
    for tw in db["tweaks"]:
        tid = tw["id"]
        print(f"- {tid}")
        if tid in seen_ids:
            fail(f"{tid}: duplicate id")
        seen_ids.add(tid)
        if tw["category"] not in CATEGORIES:
            fail(f"{tid}: unknown category {tw['category']!r}")
        for field in ("name", "description"):
            loc = tw.get(field, {})
            if not (loc.get("en") and loc.get("uk")):
                fail(f"{tid}: {field} must have non-empty en and uk")

        params = {p["key"]: p for p in tw["params"]}
        for p in tw["params"]:
            for v_name in ("originalValue", "defaultValue", "min", "max"):
                if not isinstance(p[v_name], int):
                    fail(f"{tid}: param {p['key']}.{v_name} is not an integer")
            if not (p["min"] <= p["defaultValue"] <= p["max"]):
                fail(f"{tid}: param {p['key']} default {p['defaultValue']} "
                     f"outside [{p['min']}, {p['max']}]")
            if not (p["name"].get("en") and p["name"].get("uk")):
                fail(f"{tid}: param {p['key']} name must have en and uk")
            for preset in p.get("presets", []):
                if not (p["min"] <= preset["value"] <= p["max"]):
                    fail(f"{tid}: param {p['key']} preset {preset['value']} "
                         f"outside [{p['min']}, {p['max']}]")

        originals = {p: pp["originalValue"] for p, pp in params.items()}
        defaults = {p: pp["defaultValue"] for p, pp in params.items()}
        used_keys = set()

        for idx, oper in enumerate(tw["operations"]):
            n_ops += 1
            tag = f"{tid} op[{idx}] ({oper['file']})"
            text = load_file(PRISTINE_DIR, oper["file"])
            orig, repl = oper["original"], oper["replacement"]

            # (d) placeholders reference declared params; non-param brace
            # tokens must be literal game text present in `original` too
            keys = param_keys(repl, params)
            used_keys.update(keys)
            for k in PLACEHOLDER_RE.findall(repl):
                if k not in params and ("{%s}" % k) not in orig:
                    fail(f"{tag}: undeclared placeholder {{{k}}} (not a param "
                         f"and not literal text from original)")
            for k in PLACEHOLDER_RE.findall(orig):
                if k in params:
                    fail(f"{tag}: param placeholder {{{k}}} in original")

            # (a) original occurs exactly expectedCount times in pristine file
            count = text.count(orig)
            if count != oper["expectedCount"]:
                fail(f"{tag}: original found {count} times, "
                     f"expectedCount={oper['expectedCount']}")

            # occurrence sanity
            occ = oper["occurrence"]
            if occ != "all":
                if (not isinstance(occ, list) or not occ or
                        any(not isinstance(i, int) or i < 1 or
                            i > oper["expectedCount"] for i in occ)):
                    fail(f"{tag}: bad occurrence {occ!r}")

            # (b) render(replacement, originalValues) == original.
            # Structural ops are deliberate block rewrites — exempt from round-trip.
            if oper.get("structural"):
                pass
            elif keys:
                rendered_orig = render(repl, originals)
                if rendered_orig != orig:
                    fail(f"{tag}: replacement rendered with originalValues "
                         f"does not reproduce original")
            else:
                if repl == orig:
                    fail(f"{tag}: no-param operation where replacement == "
                         f"original (no-op)")

            # (c) schema regex matches replacement rendered with defaults
            rendered_default = render(repl, defaults)
            rx = build_regex(repl, params)
            m = rx.search(rendered_default)
            if not m:
                fail(f"{tag}: schema regex does not match replacement "
                     f"rendered with defaults")
            elif keys:
                got = [int(g) for g in m.groups()]
                want = [defaults[k] for k in keys]
                if got != want:
                    fail(f"{tag}: capture groups {got} != default params {want}")

        unused = set(params) - used_keys
        if unused:
            fail(f"{tid}: declared params never used: {sorted(unused)}")

    print(f"\nChecked {len(db['tweaks'])} tweaks, {n_ops} operations.")


def tweak_status(tw, directory):
    """Schema detection semantics. Returns (status, detail)."""
    declared = {p["key"] for p in tw["params"]}
    op_states = []
    for oper in tw["operations"]:
        try:
            text = load_file(directory, oper["file"])
        except FileNotFoundError:
            return "conflict", f"{oper['file']} missing"
        if text.count(oper["original"]) == oper["expectedCount"]:
            op_states.append(("not applied", None))
        else:
            m = build_regex(oper["replacement"], declared).search(text)
            if m:
                keys = param_keys(oper["replacement"], declared)
                vals = {k: int(v) for k, v in zip(keys, m.groups())}
                op_states.append(("applied", vals))
            else:
                op_states.append(("conflict", oper["file"]))

    states = {s for s, _ in op_states}
    if states == {"not applied"}:
        return "not applied", ""
    if states == {"applied"}:
        merged = {}
        for _, vals in op_states:
            if vals:
                merged.update(vals)
        detail = (" params: " + ", ".join(f"{k}={v}" for k, v in merged.items())
                  if merged else "")
        return "applied", detail
    if "conflict" in states:
        bad = [d for s, d in op_states if s == "conflict"]
        return "conflict", f" (no match in: {', '.join(map(str, bad))})"
    return "conflict", " (operations disagree: partially applied)"


def status_report(db, directory):
    print(f"\nStatus report against: {directory}")
    width = max(len(t["id"]) for t in db["tweaks"])
    for tw in db["tweaks"]:
        status, detail = tweak_status(tw, directory)
        print(f"  {tw['id']:<{width}}  {status}{detail}")


def main():
    with open(DB_PATH, encoding="utf-8") as f:
        db = json.load(f)
    if db.get("schemaVersion") != 1:
        fail(f"schemaVersion is {db.get('schemaVersion')!r}, expected 1")
    if db.get("gameVersion") != "3.9.5":
        fail(f"gameVersion is {db.get('gameVersion')!r}, expected '3.9.5'")

    print(f"Validating {os.path.normpath(DB_PATH)} against pristine files\n")
    validate(db)

    if failures:
        print(f"\nRESULT: {len(failures)} failure(s)")
        for f_ in failures:
            print(f"  - {f_}")
        sys.exit(1)
    print("RESULT: all checks passed")

    if "--status" in sys.argv:
        status_report(db, CURRENT_DIR)


if __name__ == "__main__":
    main()
