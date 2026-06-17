#!/usr/bin/env python3
import os, re, sys

# Warband Module System opcode table (third-party, NOT committed — see .gitignore).
# Fetch it next to this script with:
#   gh api -H "Accept: application/vnd.github.raw" \
#     /repos/OutlawByteStudios/Persistent-Kingdoms/contents/header_operations.py \
#     > header_operations.py
HO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "header_operations.py")

# --- parse opcode table: name = <int> (decimal or hex), pure-int RHS only ---
code2name = {}
name2code = {}
rx = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(0x[0-9a-fA-F]+|\d+)\s*(#.*)?$')
for line in open(HO, encoding="latin-1"):
    m = rx.match(line)
    if not m:
        continue
    name, val = m.group(1), m.group(2)
    code = int(val, 16) if val.startswith("0x") else int(val)
    name2code[name] = code
    # keep first canonical name for a given code
    if code not in code2name:
        code2name[code] = name

NEG = 0x80000000
TON = 0x40000000

TAGS = {
    0: "",        # literal
    1: "reg",
    2: "g",       # global var
    3: "str",
    4: "itm",
    5: "trp",
    6: "fac",
    7: "qst",
    8: "ptpl",
    9: "party",
    10: "scn",
    11: "mtpl",
    12: "menu",
    13: "script",
    14: "psys",
    15: "sprop",
    16: "snd",
    17: "L",      # local var
    18: "micon",
    19: "skill",
    20: "mesh",
    21: "pres",
    22: "qstr",
}
SHIFT = 1 << 56
MASK = SHIFT - 1

def operand(v):
    v = int(v)
    if v < 0:
        return str(v)
    tag = v >> 56
    idx = v & MASK
    if tag == 0:
        return str(v)
    name = TAGS.get(tag, f"tag{tag}")
    if tag == 2:   # global var -> show variables.txt line number (idx+1)
        return f"g.{idx}(ln{idx+1})"
    if tag == 17:  # local var
        return f":{idx}"
    return f"{name}:{idx}"

def opname(op):
    pfx = ""
    if op & NEG:
        pfx += "neg|"; op ^= NEG
    if op & TON:
        pfx += "this_or_next|"; op ^= TON
    return pfx + code2name.get(op, f"OP_{op}")

def decode(path, label):
    toks = open(path, encoding="latin-1").read().split()
    toks = [int(t) for t in toks]
    nops = toks[0]
    i = 1
    out = []
    for k in range(nops):
        op = toks[i]; i += 1
        nargs = toks[i]; i += 1
        args = toks[i:i+nargs]; i += nargs
        name = opname(op)
        argstr = ", ".join(operand(a) for a in args)
        out.append(f"{k:4d} | {name}({argstr})")
    res = f"==== {label}  ({nops} ops, {len(toks)} tokens, consumed {i}) ====\n" + "\n".join(out)
    open(f"/tmp/sim/{label}.decoded.txt","w").write(res+"\n")
    return res

for f,l in [("game_event_simulate_battle.txt","game_event_simulate_battle"),
            ("calculate_battle_advantage.txt","calculate_battle_advantage"),
            ("simulate_battle_with_agents_aux.txt","simulate_battle_with_agents_aux")]:
    decode(f"/tmp/sim/{f}", l)
    print(f"decoded {l}")
print("OK")
