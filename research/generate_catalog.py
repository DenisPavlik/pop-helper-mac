#!/usr/bin/env python3
"""Generate tweak-catalog.md from the structured dump of the PoP3 wiki Tweaks page.

Input : research/raw/pop_tweaks_structured_decoded.md  (DOM-serialized wiki page,
        code in fenced blocks, colored spans as HIGHLIGHTS annotations)
Output: research/tweak-catalog.md
"""
import re
import unicodedata
from collections import OrderedDict

SRC = "/Users/denys/Documents/Programming/pop-helper-mac/research/raw/pop_tweaks_structured_decoded.md"
OUT = "/Users/denys/Documents/Programming/pop-helper-mac/research/tweak-catalog.md"

text = open(SRC, encoding="utf-8").read()
lines = text.split("\n")

CAT_RE = re.compile(r"^## (\d+)\. (.+?) \((\d+)\)$")
TWEAK_RE = re.compile(r"^### Tweak (\d+) ([a-z])\)$")
FILE_RE = re.compile(r"\b([a-z_0-9]+\.(?:txt|csv|ini))\b")

# ---------------------------------------------------------------- parse
categories = OrderedDict()  # num -> name
tweaks = []  # dicts

cur_cat = None
cur = None
in_code = False
i = 0
started = False
for idx, line in enumerate(lines):
    if line.startswith("```"):
        in_code = not in_code
    if in_code and not line.startswith("```"):
        if cur is not None:
            cur["body"].append(line)
        continue
    m = CAT_RE.match(line)
    if m and not in_code:
        cur_cat = (m.group(1), m.group(2))
        categories[m.group(1)] = m.group(2)
        if cur:
            tweaks.append(cur)
            cur = None
        started = True
        continue
    m = TWEAK_RE.match(line)
    if m and not in_code:
        if cur:
            tweaks.append(cur)
        cur = {
            "cat_num": cur_cat[0],
            "cat_name": cur_cat[1],
            "num": m.group(1),
            "letter": m.group(2),
            "body": [],
        }
        continue
    if cur is not None:
        cur["body"].append(line)
if cur:
    tweaks.append(cur)

# ---------------------------------------------------------------- per-tweak fields
STOPWORDS = {
    "the", "a", "an", "of", "and", "or", "to", "be", "able", "for", "with",
    "in", "on", "your", "you", "that", "which", "it", "its", "at", "by",
    "as", "is", "are", "do", "does", "etc", "various", "certain", "some",
    "given", "amount", "way", "how", "when", "upon", "after", "from",
    "get", "gets", "their", "them", "they",
}

used_ids = {}


def make_id(name: str) -> str:
    s = re.sub(r"[*_]", "", name).lower()
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    words = re.findall(r"[a-z0-9]+", s)
    if words and words[0] == "to":
        words = words[1:]
    kept = [w for w in words if w not in STOPWORDS]
    if not kept:
        kept = words
    out = []
    ln = 0
    for w in kept:
        if ln + len(w) + 1 > 58 and out:
            break
        out.append(w)
        ln += len(w) + 1
    base = "-".join(out) or "tweak"
    if base in used_ids:
        used_ids[base] += 1
        base = f"{base}-{used_ids[base]}"
    else:
        used_ids[base] = 1
    return base


def clean_inline(s: str) -> str:
    s = re.sub(r"⟦[^⟧]*⟧", "", s)
    return s


for t in tweaks:
    body = t["body"]
    # strip leading/trailing blank lines
    while body and not body[0].strip():
        body.pop(0)
    while body and not body[-1].strip():
        body.pop()
    # name & credits from first bold line
    name, credits = None, None
    for ln in body:
        m = re.match(r"^\*\*(.+)\*\*\s*(?:-\s*credits to (.+))?$", ln.strip())
        if m:
            name = m.group(1).strip()
            credits = m.group(2).strip() if m.group(2) else None
            break
    if name is None:
        name = f"Tweak {t['num']} {t['letter']})"
    t["name"] = re.sub(r"[*]", "", clean_inline(name))
    t["credits"] = credits
    t["ref"] = f"Tweak {t['num']} {t['letter']})"
    t["key"] = f"{t['num']}{t['letter']}"

    # files: declared via **Files:** bullets or **File: x** lines
    declared = []
    in_files_list = False
    in_c = False
    prose_files = []
    open_files = []
    for ln in body:
        if ln.startswith("```"):
            in_c = not in_c
            continue
        if in_c:
            continue
        s = ln.strip()
        fm = re.match(r"^\*\*Files?:\s*([^*]*)\*\*$", s) or re.match(r"^\*\*Files?:\*\*\s*(.*)$", s)
        if fm:
            rest = fm.group(1).strip()
            for f in FILE_RE.findall(rest):
                if f not in declared:
                    declared.append(f)
            in_files_list = rest == ""
            continue
        if in_files_list:
            if not s:
                continue
            bm = re.match(r"^-\s+(.*)$", s)
            if bm and FILE_RE.search(bm.group(1)):
                for f in FILE_RE.findall(bm.group(1)):
                    if f not in declared:
                        declared.append(f)
                continue
            in_files_list = False
        # prose mentions
        cl = clean_inline(s)
        for m2 in re.finditer(r"[Oo]pen _?([a-z_0-9]+\.(?:txt|csv|ini))_?", cl):
            if m2.group(1) not in open_files:
                open_files.append(m2.group(1))
        for f in FILE_RE.findall(cl):
            if f not in prose_files:
                prose_files.append(f)
    if declared:
        files = declared
    elif open_files:
        files = open_files
    else:
        files = prose_files[:3]
    t["files"] = files
    t["primary"] = files[0] if files else "other"

    # cleaned body
    t["body_out"] = "\n".join(clean_inline(ln) if not ln.startswith("```") else ln for ln in body)
    t["id"] = make_id(t["name"])

by_key = {t["key"]: t for t in tweaks}

# ---------------------------------------------------------------- grouping
GROUP_ORDER = [
    "scripts.txt", "menus.txt", "simple_triggers.txt", "conversation.txt",
    "dialog_states.txt", "triggers.txt", "mission_templates.txt",
    "troops.txt", "item_kinds1.txt", "party_templates.txt", "parties.txt",
    "factions.txt", "quests.txt", "skills.txt", "strings.txt",
    "quick_strings.txt", "variables.txt", "game_menus.csv", "module.ini",
]
groups = OrderedDict()
for f in GROUP_ORDER:
    groups[f] = []
for t in tweaks:
    groups.setdefault(t["primary"], []).append(t)
# drop empty groups
groups = OrderedDict((k, v) for k, v in groups.items() if v)


def esc_cell(s):
    return s.replace("|", "\\|")


# ---------------------------------------------------------------- special-interest section
SPECIAL = [
    ("1a", "Unique spawns (e.g. Wolfbode the Slayer) escaping after battle. Capture works when "
           "`x + 5 * PrisonerManagement >= 60` (x is a value pre-rolled every 120 h). Changing the "
           "threshold **60** to **-100** makes unique spawn leaders and lords ALWAYS be captured "
           "(even when a Noldor lord fought alongside you); **0** = always captured except in "
           "Noldor-lord battles; **150** = never captured. Edit `2147483678 2 1224979098644774956 60` "
           "in menus.txt (menu_total_victory) plus the two instances of "
           "`4 0 30 2 1224979098644774957 60` in scripts.txt (party_calculate_loot; 1st = Eyegrim, "
           "2nd = the Three Seers)."),
    ("1b", "Relation threshold below which unique spawn leaders can still be captured "
           "(menus.txt, single number, default 0)."),
    ("7a", "Maximum Qualis Gem chance at Noldor tournaments: in menus.txt search "
           "`2 144115188075857282 20` and change **20** to **100** — the prize is then always a "
           "Qualis Gem. The same tweak also shows how to un-preroll the prize and how to replace "
           "the entire reward table."),
    ("17h", "Recruit Noldor troops: full replacement of the `party_add_party_prisoners` script body "
            "in scripts.txt makes rescued Noldor prisoners (Warriors/Rangers/Maiden Rangers/Nobles/"
            "Twilight Knights) recruitable, scaling with Noldor relation. All thresholds tunable."),
    ("17u", "Amount of Noldor troops Quigfen/Arandur give per Qualis Gem (conversation.txt, "
            "four dialog lines, all unit counts tunable)."),
    ("7g", "Increased tournament rewards: renown (**20**), town relation (**3**), denars (**2000**) "
           "and XP (**250**) after winning a tournament — all in one menus.txt line "
           "(menu_town_tournament_won)."),
    ("7f", "Tournament bets based on renown: replace the `mno_bet_500` line in menus.txt so bets "
           "scale 1:1 with your renown (100%/50%/20%/10%/5% submenu)."),
    ("7c", "Number of Noldor tournament wins required for the Mystical Rune Plate "
           "(conversation.txt, default 10)."),
    ("16a", "Disable unhappy companions from leaving the party (simple_triggers.txt + triggers.txt "
            "+ conversation.txt)."),
    ("16c", "Disable companion complaints — about each other and about your deeds "
            "(scripts.txt + simple_triggers.txt; change the relevant 1025 opcodes to 31)."),
    ("15d", "Chance of prisoner lords escaping from party/garrison (simple_triggers.txt; "
            "set `20 2121 3 1224979098644774913 400` and `10 2121 3 1224979098644774913 200` "
            "values to 0 0 to disable)."),
    ("19c", "Overhaul of the player's prisoner capacity / Prisoner Management scaling."),
    ("16o", "All companions contribute their Prisoner Management skill to the prisoner limit."),
    ("5a", "Remove the faction relation caps."),
    ("13n", "Change the garrison size of walled fiefs."),
    ("12e", "Change the wages of troops (incl. garrisoned troops — garrison cost)."),
]

# ---------------------------------------------------------------- emit
out = []
A = out.append

A("# Prophesy of Pendor 3.9.5 — Tweak Catalog")
A("")
A("Compiled 2026-06-12 for the PoP Helper macOS app. Unless noted otherwise, every entry was "
  "made for / updated to **PoP v3.9.5.1** (the hotfixed 3.9.5, identical to the v3.9.5.6.zip on "
  "ModDB) according to the source wiki. All search/replace strings are copied verbatim from the "
  "source.")
A("")
A("## Sources")
A("")
A("- **Primary:** PoP3 Wiki \"Tweaks\" page — <https://pop3.fandom.com/wiki/Tweaks> "
  "(292 tweaks, stated version v3.9.5.1; full page retrieved 2026-06-12, raw dump in "
  "`research/raw/pop_tweaks_structured_decoded.md`)")
A("- PoP3 Wiki \"Tweaking guide\" — <https://pop3.fandom.com/wiki/Tweaking_guide> "
  "(file-format conventions only, no tweak list)")
A("- Steam guide \"Prophesy of Pendor Tweaking\" — "
  "<https://steamcommunity.com/sharedfiles/filedetails/?id=908829523> "
  "(one tool-based tweak, see appendix)")
A("- Steam guide \"PoP Helper [3.9.1]\" — "
  "<https://steamcommunity.com/sharedfiles/filedetails/?id=1529221584> "
  "(feature list of the Windows PoP Helper app, see appendix)")
A("- Russian tweak thread referenced by both the wiki and PoP Helper: "
  "<http://rusmnb.ru/index.php?topic=20941.0> (original source of many tweaks; superseded by the wiki list)")
A("")
A("## How tweaks are applied (conventions)")
A("")
A("- All edits target the compiled `.txt` files in `Modules/Prophesy of Pendor V3.9/`.")
A("- Search strings are space-sensitive: single spaces separate numbers, double spaces separate "
  "code blocks. Always match gaps exactly; a replacement must keep exactly one space on each side "
  "unless stated otherwise.")
A("- Many files start with a counter (2nd or 1st line) that must be incremented when entries are "
  "appended (e.g. quick_strings.txt 3139 -> 3140). Scripts/triggers/menus/dialogs begin with an "
  "operation counter that must be adjusted when operations are added/removed; the instructions "
  "state the exact delta each time.")
A("- `HIGHLIGHTS:` annotations after a code block list the values that were color-marked on the "
  "wiki — these are the tunable parameters (and, for multi-color tweaks, the cross-file ID numbers "
  "that may need recalculation when combined with other tweaks). The body text explains each.")
A("- Default values shown in the search strings are the v3.9.5.1 stock values.")
A("")
A("## Coverage notes")
A("")
A("- The wiki page is the authoritative, version-correct (3.9.5.1) source; all 292 tweaks from it "
  "are cataloged below with their full verbatim instructions and code.")
A("- The colored in-line code highlighting of the wiki cannot be represented in plain code blocks; "
  "it is preserved as `HIGHLIGHTS:` annotation lines immediately after each affected code block, "
  "in document order. Color names match the wiki's prose (\"change the red value\", etc.).")
A("- A few tweaks additionally reference screenshots or downloadable resource packs "
  "(e.g. Tweak 18 c/d/e/f item meshes via OpenBRF, Tweak 16 q Custom Commander, Tweak 21 j "
  "terrain textures); those binary assets are NOT captured here — only the .txt edits are.")
A("- The Steam guide 908829523 contains no .txt search/replace tweaks — only a Morgh's-Editor "
  "procedure (appendix). It was written for PoP ~3.6 but is version-agnostic (tool-based).")
A("- The PoP Helper [3.9.1] Steam guide does NOT publish the app's full in-app tweak list; it only "
  "names the 7 tweaks added in its v3.9 (honor loss for caravan tribute; garrison info via "
  "companions; remove tax inefficiency; Troop Tree button; looped tavern/arena sound fix; disable "
  "player luck; renounce oath keeping fiefs) and 3 removed ones (control village garrisons; CKO "
  "smith upgrade time; autosave). All of these map to wiki tweaks cataloged below (4 a, 16 h, "
  "12 c, 17 n, 21 m, 21 b, 15 r). Its remaining tweaks come from rusmnb.ru topic 20941 and "
  "overlap with this catalog; the in-app list itself could not be retrieved (Windows app only).")
A("- The wiki's \"Tweak Requests\" section lists tweaks that do **not** exist; they are excluded.")
A("- Tweaks marked by the wiki as TweakMB-editable can also be applied via TweakMB "
  "(load as PoP 3.611); TweakMB's own generic tweak set is not separately itemized here.")
A("- module.ini settings (battle size cap, etc.) are not part of the wiki tweak list and are not "
  "itemized here.")
A("")

# special-interest
A("## Special-interest tweaks (quick reference)")
A("")
for key, comment in SPECIAL:
    t = by_key.get(key)
    if not t:
        A(f"- **{key}**: NOT FOUND — {comment}")
        continue
    A(f"- [`{t['id']}`](#{t['id']}) ({t['ref']}, primary file: {t['primary']}): {comment}")
    A("")
A("")

# index
A("## Index of all tweaks")
A("")
A("| ID | Wiki ref | Name | Files modified |")
A("|---|---|---|---|")
for t in tweaks:
    nm = esc_cell(re.sub(r"[*_]", "", t["name"]))
    fl = esc_cell(", ".join(t["files"]) if t["files"] else "(tool-based / see entry)")
    A(f"| [`{t['id']}`](#{t['id']}) | {t['ref']} | {nm} | {fl} |")
A("")

# groups
A("---")
A("")
A("# Catalog (grouped by primary file modified)")
A("")
for fname, ts in groups.items():
    title = fname if fname != "other" else "Other / tool-based"
    A(f"## {title} ({len(ts)} tweaks)")
    A("")
    for t in sorted(ts, key=lambda x: (int(x["num"]), x["letter"])):
        A(f"### {t['id']}")
        A("")
        A(f"- **Name:** {re.sub(r'[*_]', '', t['name'])}")
        A(f"- **Wiki ref:** {t['ref']} — category {t['cat_num']}. {t['cat_name']}")
        if t["credits"]:
            A(f"- **Credits:** {re.sub(r'[*_]', '', clean_inline(t['credits']))}")
        A(f"- **Files modified:** {', '.join(t['files']) if t['files'] else '(tool-based / see instructions)'}")
        A("- **Version:** PoP 3.9.5.1")
        A("")
        A("**Instructions (verbatim from the wiki):**")
        A("")
        A(t["body_out"])
        A("")
        A("---")
        A("")

# appendix
A("# Appendix: tweaks from the Steam guides")
A("")
A("### morghs-recruitable-undead-and-ko-units")
A("")
A("- **Name:** Make Undead / Knighthood-Order units recruitable from prisoners")
A("- **Source:** Steam guide \"Prophesy of Pendor Tweaking\" "
  "(<https://steamcommunity.com/sharedfiles/filedetails/?id=908829523>)")
A("- **Files modified:** troops.txt (via Morgh's M&B Editor — not a text search/replace)")
A("- **Version:** written for PoP ~3.6, tool-based and version-agnostic; works on 3.9.5 "
  "(uncertain only in that the guide predates 3.9.5)")
A("")
A("Procedure: open the PoP module in Morgh's Editor (text-compiled mode) -> Troop Editor; for every "
  "troop you want capturable/recruitable, set its level below 35 and uncheck the \"Fall Dead\" "
  "flag, then save. Optionally use TweakMB (load module as \"Prophesy of Pendor 3.611\") -> "
  "Prisoners -> Recruiting Prisoners to remove the morale penalty and recruit-frequency limits.")
A("")
A("### pop-helper-windows-app (reference, not a tweak)")
A("")
A("- **Source:** Steam guide \"PoP Helper [3.9.1]\" "
  "(<https://steamcommunity.com/sharedfiles/filedetails/?id=1529221584>), final version 3.9.1 "
  "(2020-09-12), supports PoP 3.9.5/3.9.5.1.")
A("- Offers: tweak installation (set adapted to 3.9.5.1), Russian localization, save/file backups, "
  "save repair, module.ini editor, character-creation tab, import/export editor, mod installer "
  "(Delzaros UI Pack, Cursor Changer, Economics of Pendor, female faces, compressed textures, "
  "Music Pack, Arena Overhaul, Polished Landscape, collision fix, cows-on-water fix, Old Qualis "
  "Gem, No Dot Main Menu) and 12 font options.")
A("- Tweaks marked with * in the app require a new game and cannot be removed mid-save.")
A("")

open(OUT, "w", encoding="utf-8").write("\n".join(out) + "\n")

# ---------------------------------------------------------------- report
print(f"tweaks parsed: {len(tweaks)}")
print(f"groups: {[(k, len(v)) for k, v in groups.items()]}")
nofile = [t['ref'] for t in tweaks if not t['files']]
print(f"tweaks with no detected files ({len(nofile)}): {nofile}")
noname = [t['ref'] for t in tweaks if t['name'].startswith('Tweak ')]
print(f"tweaks with no parsed name: {noname}")
import os
print(f"output size: {os.path.getsize(OUT)} bytes")
