#!/usr/bin/env python3
import re
PRISTINE = ("/Users/denys/Library/Application Support/Steam/steamapps/common/"
            "MountBlade Warband/Modules/Prophesy of Pendor V3.9.5/_backupHelper/"
            "Backup Your Files/[Tweaks] 26.10.23       15-03-18/scripts.txt")
LIVE = ("/Users/denys/Library/Application Support/Steam/steamapps/common/"
        "MountBlade Warband/Modules/Prophesy of Pendor V3.9.5/scripts.txt")

def get_body(path, name):
    lines = open(path, encoding="latin-1").read().split("\n")
    for i,l in enumerate(lines):
        if l.startswith(name+" ") and l.rstrip().endswith("-1"):
            return lines[i+1]
    raise SystemExit("not found "+name)

def op_spans(body):
    toks = body.split()
    nops = int(toks[0])
    i = 1
    spans = []   # (op_index, start_tok, end_tok)
    for k in range(nops):
        start = i
        op = int(toks[i]); i+=1
        nargs = int(toks[i]); i+=1
        i += nargs
        spans.append((k, start, i))
    return toks, spans

for path,label in [(PRISTINE,"PRISTINE"),(LIVE,"LIVE")]:
    body = get_body(path, "game_event_simulate_battle")
    toks, spans = op_spans(body)
    # slice ops 66..74 inclusive and 89..90 inclusive
    def slice_ops(a,b):
        start = spans[a][1]; end = spans[b][2]
        return " ".join(toks[start:end])
    block_div = slice_ops(66,74)
    block_floor = slice_ops(89,90)
    full = open(path, encoding="latin-1").read()
    print(f"==== {label} ====")
    print("DIV BLOCK (ops66-74):")
    print(" ", block_div)
    print("FLOOR BLOCK (ops89-90):")
    print(" ", block_floor)
    # uniqueness of literal
    print("literal counts in whole file: div=%d floor=%d" %
          (full.count(block_div), full.count(block_floor)))
    # wildcarded regex (replace the tunable numbers with (-?\d+))
    # div: 30,30,90,90 are at specific positions -> build regex by replacing them
    div_rx = re.escape(block_div)
    # replace the standalone numbers 30 and 90 (escaped) carefully: do it on token level
    dt = block_div.split()
    # tunable token indices within div block: find positions of '30' and '90'
    div_tmpl = []
    for t in dt:
        if t=="30": div_tmpl.append("{lowdiv}")
        elif t=="90": div_tmpl.append("{highdiv}")
        else: div_tmpl.append(t)
    div_tmpl=" ".join(div_tmpl)
    ft = block_floor.split()
    floor_tmpl=" ".join("{floor}" if t=="5" else t for t in ft)
    def to_rx(tmpl):
        parts=[]; pos=0
        for m in re.finditer(r"\{[a-z]+\}", tmpl):
            parts.append(re.escape(tmpl[pos:m.start()])); parts.append(r"(-?\d+)"); pos=m.end()
        parts.append(re.escape(tmpl[pos:]))
        return re.compile("".join(parts))
    print("wildcarded counts: div=%d floor=%d" %
          (len(to_rx(div_tmpl).findall(full)), len(to_rx(floor_tmpl).findall(full))))
    print("div template :", div_tmpl)
    print("floor template:", floor_tmpl)
    print()
