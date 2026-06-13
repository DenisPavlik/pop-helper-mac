#!/usr/bin/env python3
"""Make parameterized tweak patterns unique.

Some operations' `original`/`replacement` are too short: once the param value
becomes `\\d+`, the regex matches many coincidental places in the module file,
so status-detection / revert can't identify the right spot. This script grows
each affected op's `original` (and the matching `replacement`) outward by whole
space-delimited tokens until the parameterized regex matches the pristine file
exactly `expectedCount` times. Only ops with declared param placeholders are
touched; structural / no-param ops are left alone.

Run from repo root: python3 research/fix_ambiguous.py
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(HERE, "..", "PoPHelper", "Resources", "tweaks.json")
PRIS = ("/Users/denys/Library/Application Support/Steam/steamapps/common/"
        "MountBlade Warband/Modules/Prophesy of Pendor V3.9.5/_backupHelper/"
        "Backup Your Files/[Tweaks] 26.10.23       15-03-18")
PH = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)\}")

_cache = {}


def load(name):
    if name not in _cache:
        with open(os.path.join(PRIS, name), "rb") as f:
            _cache[name] = f.read().decode("latin-1")
    return _cache[name]


def build_regex(template, decl):
    parts, pos, has = [], 0, False
    for m in PH.finditer(template):
        if m.group(1) not in decl:
            continue
        has = True
        parts.append(re.escape(template[pos:m.start()]))
        parts.append(r"(-?\d+)")
        pos = m.end()
    parts.append(re.escape(template[pos:]))
    return re.compile("".join(parts)), has


def rx_count(template, decl, txt):
    rx, _ = build_regex(template, decl)
    return len(rx.findall(txt))


def grow_left(txt, i):
    j = i
    while j > 0 and txt[j - 1] == " ":
        j -= 1
    while j > 0 and txt[j - 1] != " ":
        j -= 1
    return j


def grow_right(txt, i):
    j = i
    while j < len(txt) and txt[j] == " ":
        j += 1
    while j < len(txt) and txt[j] != " ":
        j += 1
    return j


def fix_op(op, decl, txt):
    orig, repl = op["original"], op["replacement"]
    exp = op["expectedCount"]
    rx, has = build_regex(repl, decl)
    if not has:
        return None  # structural / no-param — not our concern
    if len(rx.findall(txt)) == exp:
        return None  # already unique enough
    s = txt.find(orig)
    if s < 0:
        return "ERR: original not found"
    e = s + len(orig)
    L, R = s, e
    for _ in range(60):
        ctxL, ctxR = txt[L:s], txt[e:R]
        oext, rext = ctxL + orig + ctxR, ctxL + repl + ctxR
        if txt.count(oext) == exp and rx_count(rext, decl, txt) == exp:
            op["original"], op["replacement"] = oext, rext
            return "fixed"
        nl, nr = grow_left(txt, L), grow_right(txt, R)
        if nl == L and nr == R:
            break
        L, R = nl, nr
    return "FAIL: could not make unique (expectedCount=%d)" % exp


def main():
    db = json.load(open(DB_PATH, encoding="utf-8"))
    fixed, failed, errors = [], [], []
    for tw in db["tweaks"]:
        decl = {p["key"] for p in tw["params"]}
        for i, op in enumerate(tw["operations"]):
            txt = load(op["file"])
            res = fix_op(op, decl, txt)
            if res == "fixed":
                fixed.append(f"{tw['id']} op{i}")
            elif res and res.startswith("FAIL"):
                failed.append(f"{tw['id']} op{i}: {res}")
            elif res and res.startswith("ERR"):
                errors.append(f"{tw['id']} op{i}: {res}")
    with open(DB_PATH, "w", encoding="utf-8") as f:
        json.dump(db, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"FIXED {len(fixed)} ops:")
    for x in fixed:
        print("  +", x)
    if failed:
        print(f"\nUNFIXABLE {len(failed)} ops (need manual handling or drop):")
        for x in failed:
            print("  !", x)
    if errors:
        print(f"\nERRORS {len(errors)}:")
        for x in errors:
            print("  ?", x)


if __name__ == "__main__":
    main()
