#!/usr/bin/env python3
"""Find the tweak(s) that crash Warband during module load, by binary search.

Strategy (each culprit crashes on its own, so isolation works):
  1. Apply the full remaining applicable set on the known-good baseline, launch the
     game. If it LOADS -> the remaining set is clean, stop.
  2. Otherwise binary-search the set: apply the left half, launch; if it CRASHES the
     culprit is in the left half, else the right half. Narrow to a single tweak.
  3. Record that culprit, remove it from the pool, go to 1.

Every test resets the mod to the baseline checkpoint first, so each subset is applied
on a clean, known-loading state. Produces /tmp/pop_bisect_report.txt.
"""
import subprocess, sys, time

HOME = "/Users/denys"
APP = f"{HOME}/Documents/Programming/pop-helper-mac/.build/debug/PoPHelper"
CK = f"{HOME}/Library/Application Support/PoP Helper Mac/Checkpoints/baseline-loads-ok"
MOD = f"{HOME}/Library/Application Support/Steam/steamapps/common/MountBlade Warband/Modules/Prophesy of Pendor V3.9.5"
HARNESS = f"{HOME}/Documents/Programming/pop-helper-mac/research/loadtest.sh"
MAXWAIT = "65"
REPORT = "/tmp/pop_bisect_report.txt"

applicable = [l.strip() for l in open("/tmp/pop_applicable_ids.txt") if l.strip()]
_log = open(REPORT, "w")
def say(m):
    _log.write(m + "\n"); _log.flush()
    print(m, flush=True)

def reset():
    subprocess.run(f'cp "{CK}"/*.txt "{MOD}"/ && cp "{CK}/module.ini" "{MOD}/"',
                   shell=True, check=True)

def loads(ids):
    """Reset, apply `ids`, launch game. Return (loaded:bool, applied_count:int)."""
    reset()
    ap = subprocess.run([APP, "--apply", ",".join(ids)], capture_output=True, text=True)
    applied = sum(1 for l in ap.stdout.splitlines() if l.startswith("APPLIED"))
    h = subprocess.run(["bash", HARNESS, MAXWAIT], capture_output=True, text=True)
    res = next((l for l in h.stdout.splitlines() if l.startswith("RESULT:")), h.stdout.strip())
    ok = "LOADED_OK" in res
    say(f"    [{len(ids)} sent / {applied} applied] -> {res}")
    return ok, applied

def find_one_culprit(candidates):
    cand = candidates[:]
    while len(cand) > 1:
        mid = len(cand) // 2
        left = cand[:mid]
        say(f"  bisect: test left half ({len(left)}/{len(cand)})")
        ok, _ = loads(left)
        if not ok:
            say("    -> left CRASHES, culprit in left")
            cand = left
        else:
            say("    -> left LOADS, culprit in right")
            cand = cand[mid:]
    return cand[0]

say(f"START bisect over {len(applicable)} applicable tweaks  {time.strftime('%H:%M:%S')}")
pool = list(applicable)
culprits = []
while True:
    test = [i for i in pool if i not in culprits]
    say(f"TEST remaining set ({len(test)} tweaks, minus {len(culprits)} known culprits)")
    ok, _ = loads(test)
    if ok:
        say("  remaining set LOADS -> all clean")
        break
    c = find_one_culprit(test)
    culprits.append(c)
    say(f">>> CULPRIT #{len(culprits)}: {c}")

reset()
say("")
say(f"DONE {time.strftime('%H:%M:%S')}")
say(f"CULPRITS ({len(culprits)}): {', '.join(culprits) if culprits else 'none'}")
say(f"SAFE applicable set: {len(applicable) - len(culprits)} tweaks load together")
