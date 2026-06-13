# PoP Helper — Reverse-Engineered Applied Tweaks (Prophesy of Pendor 3.9.5)

Analysis of `research/diffs/*.diff` (original 3.9.5 files = `<` side, tweaked 2023 files = `>` side),
cross-referenced against `research/PH_config.ini` and the community tweak guide
(`research/raw/pop_tweaks_decoded.txt`, the rusmnb/wiki tweak list that PoP Helper automates).
Guide tweak IDs below ("Tweak 7 a", etc.) refer to that document.

**Bottom line: ~60 distinct gameplay tweaks were applied**, spanning every module file in the diff set.
Decoding the `tweakch_395` QBitArray in PH_config.ini yields exactly **60 checked checkboxes (of 130)**,
which matches the number of distinct tweaks found in the diffs (the exact bit→tweak-ID mapping could not
be confirmed, so per-tweak attribution below relies on the `value395\N_x` parameter values instead).

---

## Summary table: PH_config values ↔ diff evidence

| PH config key | Value | Diff evidence | Interpretation | Confidence |
|---|---|---|---|---|
| `10_1,10_2,10_3` | 10, 20, 20 | scripts.txt:68 — party-size script: base `10` unchanged, leadership mult `10→20`, renown divisor `25→20` | Max party size: 10 base + **20/Leadership** (was 10) + renown/**20** (was /25) | **Certain** |
| `19_1` | 0 | menus.txt:386 — `…936748722493063450 -5` → `0` | Honor loss for refusing a lord-ransom offer: −5 → **0** (guide 4 b) | Likely |
| `20_1` | 5000 | menus.txt:229,231 — `2133 2 reg6 2500` → `5000` (×2 menus) | Regular tournament victory purse **2500 → 5000 denars** | **Certain** |
| `23_1` | 2000 | simple_triggers.txt:53 — town rent base `1200 → 2000` | Town base rent income **1200 → 2000** (guide 12 a) | Likely |
| `28_1,28_2` | −100, −100 | menus.txt:163 — `lt x 60` → `lt x -100` (2 instances, menu_total_victory) | Unique-spawn leaders & lords **never escape after defeat** (capture roll threshold 60 → −100, always passes) | **Certain** |
| `29_1` | 5 | conversation.txt:938 — `call change_relation(_talk_troop, 2)` → `…, 5)` | Relation gained from an NPC courtesy interaction (likely releasing a captured lord) **+2 → +5** | Likely |
| `31_4` | 9 | scripts.txt:42 — wage script: leadership discount `5 → 9` (% per point) | Troop wage reduction per Leadership point **5% → 9%** (31_1=3, 31_2=25 are the unchanged base-wage factors) | Likely |
| `36_1,36_2,36_3` | 4, 4, 3 | module.ini:63–65 — `player/hero/regulars_xp_multiplier 1.5/1.5/1 → 4.0/4.0/3.0` | XP multipliers: player ×4, heroes ×4, regular troops ×3 | **Certain** |
| `42_1` | 100 | conversation.txt:3628 — arena-win dialog: added `call change_troop_renown(player, 100)` | **+100 renown per arena melee win** (guide 7 h; default 10) | **Certain** |
| `58_1` | 30 | conversation.txt:4114 — Alexios dialog: inserted `assign upgrade_days 30` | Alexios of Melitine rune-gear upgrades take a **flat 30 days** (guide 2 b pt. 9) | **Certain** |
| `72_1` | 100 | menus.txt:325 — Noldor tournament: gem roll `lt rand 20` → `lt rand 100` | **Qualis Gem awarded 100%** of Noldor tournament wins (was 20%) | **Certain** |
| `83_1` | 100 | scripts.txt:1216 — KO-chapter chance thresholds `81/91/31/31/46/51 → 100` (6×) | Knighthood Order chapters guaranteed to spawn at game start (chance → 100%) (guide 2 g) | **Certain** |
| `105_1,105_3,105_4` | 30, 3000, 300 | menus.txt:325 — renown `20→30`, prize `2000→3000`, troop XP `250→300` | Noldor tournament rewards: **renown 30, 3000 denars, 300 XP** (guide 7 a); 105_2=3 not located (possibly param of the new helper-script call `1 2 …063906 2`) | **Certain** (105_2 unknown) |
| `34_1` | 10 | simple_triggers.txt:90 — book-reading progress per tick `7 → 10` | Books read ~43% faster | Possible |
| `130_1` | 5000 | menus.txt:640+ — new camp-training option requires/charges 5000 denars | Camp troop-training base price (value equals guide default, so unverifiable) | Possible |
| `126_1` | −10 | menus.txt:386 — `-10` present unchanged next to the 4 b edit | Default value written back (no change) | Unknown |
| `6_1,6_2`=12500,350; `12_x`; `15_1`=40000; `18_1`=12; `33_x`; `41_1`; `43_1`; `46_x`; `47_1`; `59_x`; `99_1`; `111–113_x`; `120_x`; `121_x`; `123_1`; `125_1`; `5_1` | — | **No matching change in these diffs** | Saved-but-not-applied parameters, or tweaks touching files not in the diff set (item_kinds1.txt, party_templates.txt, parties.txt, skills.txt) | Unknown |
| `Tr=0`, `ExpCheat=0` | 0 | n/a | PH extra features (trainer / free-XP cheat) disabled | Certain |
| `mods\faces1=active` | — | troops.txt flag changes (see below) | Cosmetic faces add-on pack | Likely |
| `mods\colfix=active` | — | conversation.txt:2314–2381 (kingdom colors overhaul) | "Color fix" add-on: renamed + 43 extra kingdom colors | Likely |
| `mods\ndmm=active` | — | possibly the mission-template entry-point shifts (see below) | Unidentified add-on pack | Unknown |

Note: the QBitArray decode (LSB-first, 1-based) yields checked IDs
{1,2,3,6,8,9,12,14,15,17,18,19,20,24,25,26,27,31,39,47,52,53,54,55,58,60,62,64,65,67,68,69,70,71,72,73,78,79,81,83,85,86,88,91,92,93,95,98,105,108,109,114,117,119,121,122,126,127,128,130} — the count (60) matches the
number of distinct applied tweaks, but several value-confirmed tweaks (e.g. #10, #28) are *not* in that set,
so the bit→ID alignment is unreliable and was not used for attribution.

---

## module.ini

| Location | Change | Effect | Confidence |
|---|---|---|---|
| lines 63–65 | `player_xp_multiplier 1.5→4.0`, `hero_xp_multiplier 1.5→4.0`, `regulars_xp_multiplier 1→3.0` | All experience gain massively increased (matches config 36_1/2/3 = 4/4/3) | **Certain** |
| line 145 | `can_crouch 0→1` | Enables crouching (prerequisite of guide Tweak 10 k, "crouching and bracing spears") | **Certain** |

## scripts.txt

Script count 754 → 757; **3 new scripts appended** (line 1510a1511,1516):
- `switch_weapon` — picks a replacement sidearm (`itm 288230376151712934` Sword, or `…713048` if weapon type ≥ 13/polearm). Helper for the dismount/lance-swap triggers → part of **Tweak 10 c** family. *Certain.*
- `blunt_weapons_order` — new implementation of the "use blunt weapons" order → **Tweak 10 m** (rework blunt weapons order). *Certain.*
- `game_check_party_sees_party` — **Tweak 1 t**: prevents Noldor parties from attacking caravans, farmers and militia patrols. *Certain.*

| txt line | Token change(s) | Effect | Confidence |
|---|---|---|---|
| 42 | tok179 `5→9` in `store_mul r6 = 5×Leadership; wage ×= (100−r6)/100` (game_get_troop_wage) | Wage discount per Leadership point 5% → **9%** | Certain (effect), Likely (=31_4) |
| 68 | tok22 `10→20` (leadership multiplier), tok44 `25→20` (renown divisor) in party-size script | Party size: +20/Leadership (was +10), +renown/20 (was /25) → much larger party (config 10_2/10_3) | **Certain** |
| 264 | block rewritten: now loops party companions, `store_skill_level(…, skill 2=Prisoner Management)` and adds to limit | **Tweak 16 o**: all companions' Prisoner Management adds to prisoner limit (exact guide replacement code) | **Certain** |
| 312 | +92 tokens, matches guide replacement | **Tweak 11 c**: fixes loot depending on the order troops were killed | **Certain** |
| 316 | counter 13→9; per-troop share loop deleted; companion share `+3 → +0` (calculate_main_party_shares) | **Tweak 11 a**: regular troops (and companions) no longer take loot shares → player gets far more loot | **Certain** |
| 332 | rewritten; new side matches guide 15 i replacement | **Tweak 15 i**: own-kingdom lords hire only rescued troops matching your culture | Likely |
| 468 | tok526 `-5→0` in `val_clamp(rel_change, -5, 3)` | **Tweak 5 f/5 g**: no relation *loss* with vassals when distributing fiefs (clamp floor −5 → 0) | **Certain** |
| 488 | counter 620→615, try-block removed (old matches guide 13 h search snippet) | **Tweak 13 h**: conquered fiefs with deferred assignment recruit *your* faction's troops | Likely |
| 524 | counter 171→177; inserted `if dist<30 → msg qstr_15021 / if dist<60 → msg qstr_15022` (color 16732240) | **Tweak 1 i** family: automatic sighting reports about unique spawns / minor-faction armies, gated by distance | **Certain** (purpose), param source unknown |
| 536 | counter 142→145; new side matches guide 15 a replacement | **Tweak 15 a**: lords refuse to raid villages under certain conditions | **Certain** |
| 636, 654, 732, 734, 1310, 1334 | rewrites; new sides match guide 10 c snippets (`agent_slot 46` horse handling, `2147484193 3 r 46 …`) | **Tweak 10 c**: mounted foot units reassigned to cavalry, dehorsed unit handling/commandability fixes | **Certain** |
| 680 | tok73 `2500 → 10000000000` in `val_min($renown_gain, …)` (calculate_renown_value) | **Tweak 4 e**: per-battle renown gain cap (2500) effectively removed | **Certain** |
| 776 | tok31 `1→0` (assign r3) in an agent/encounter-side script | Possibly **Tweak 10 f** (relaxed requirements to command allied units) | Unknown/low |
| 1216 | 6 thresholds `81,91,31,31,46,51 → 100` (`lt rand X` before `party_set_slot(stronghold, 289, troop)`) | **Tweak 2 g**: KO chapters guaranteed in walled fiefs at new-game start (config 83_1=100) | **Certain** |

## menus.txt

Menu count 319 → 320 (new camp-training menu added).

| txt line | Change | Effect | Confidence |
|---|---|---|---|
| 127 | menu_camp_recruit_prisoners ops 108→76; removed checks (incl. `lt r6 40`, honor gates) | **Tweak 17 e**: restrictions on recruiting prisoners removed | **Certain** |
| 149 | menu_simple_encounter ops 123→100; deleted exactly the guide 8 k block (`541 3 …187 4 5 …`) | **Tweak 8 k**: village raids by lords fought as normal field battles (no village scene ambush) | **Certain** |
| 161 | menu_battle_debrief ops 157→163; inserted loop restoring riding skill from troop slot 501 | Part of **Tweak 10 c** (step 4: foot units get riding skill back after battle; exact guide code) | **Certain** |
| 163 | menu_total_victory ops 475→477; capture roll `lt x 60 → lt x -100` (×2) + inserted re-roll branch for lord troop range | **Unique spawn leaders and lords never escape** — always capturable after you defeat them (config 28_1/28_2 = −100) | **Certain** |
| 172 | relation gates `-50→-200` and `80→200` (×2) on "Move in to help…/Rush to the aid…" options | **Tweak 10 u**: you can join (either side of) almost any battle regardless of relations | **Certain** |
| 229, 231 | `assign reg6 2500 → 5000` (tournament-won menus) | Tournament prize money 2500 → **5000** (config 20_1) | **Certain** |
| 265 | `store_div r5 = cost/150 → /450` (+3 days) | **Tweak 13 v**: fief improvements build ~3× faster | **Certain** |
| 303–304 | option count 15→16; added `mno_camp_station_troops … Manage_the_garrison.` gated on KO-quest slot 11 ≥ 5 | **Tweak 2 a**: direct access to your Knighthood Order stronghold's garrison | **Certain** |
| 325 | Noldor tournament victory menu rewritten: renown `20→30`, prize `2000→3000`, XP `250→300`; Qualis-gem roll `lt rand 20 → lt rand 100`; new call `script …063906(2)`; extra gem/item branches (`itm …713176/713177`) | **Tweak 7 a**: bigger Noldor tournament rewards + **guaranteed Qualis Gem** (configs 105_x, 72_1) | **Certain** |
| 334 | fixed bets (`500/250/100/50/20` denars) replaced by `mno_bet_100/50/20/10/5` computing % of a renown-based max (`troop slot 7` renown; div/mul pairs 1/1, 2/1, 5/1, 10/1, 20/1) | **Tweak 7 f**: tournament bets scale with your renown (bet 100%/50%/20%/10%/5% of renown-based max) | **Certain** |
| 386 | `call script …063450, -5 → 0` | **Tweak 4 b**: no honor loss when refusing a ransom offer for a lord (config 19_1=0) | **Certain** |
| 387–388, 640+ | camp menus: +1 option `mno_camp_train_troops  Train_troops.`; new menu `menu_camp_train_troops_variants` with 3 paid programs: 10 000 XP/5 000 d, 50 000 XP/20 000 d, 150 000 XP/50 000 d (30 000 XP per-troop cap); failure msg `Not_enough_money.` | **Camp troop training** (guide 17 c variant): buy party XP at camp for denars | **Certain** |

## conversation.txt

Dialog count 4152 → 4203 (+51).

| txt line | Change | Effect | Confidence |
|---|---|---|---|
| 911–912 | removed `lt $g_garrison_strength 2000` / `… 4000` conditions from `dlga_player_siege_ask_surrender:*` | **Tweak 9 h**: besieged defenders consider surrender based purely on 5:1 / 3:1 force ratio (garrison-size floor removed) | **Certain** |
| 938 | `call …063443($g_talk_troop, 2 → 5)` (+1 honor call unchanged) | NPC interaction relation gain +2 → **+5** (likely releasing captured lord; guide 5 k family; config 29_1=5) | Likely |
| 1431 | `dlga_lord_give_troops`: `2056 1 r0` → `2043 2 0 r0` (give-screen → exchange-screen) | **Tweak 15 q**: giving troops to vassals/lords becomes a mutual exchange | **Certain** |
| 2287a2288 | added `dlga_steward_menu:pop2_war_room_create_order … I_want_to_create_a_chapter_of_a_Knighthood_Order...` | **Tweak 2 j**: create KO chapters in any walled fief of your kingdom | **Certain** |
| 2288a2290 | added `dlga_steward_menu:dismantle_ko_confirm … I_want_to_dismantle_the_Knighthood_Order…` | **Tweak 2 l**: dismantle KO chapters in your fiefs | **Certain** |
| 2314–2381 | color options renamed (e.g. Yellow→Golden_Yellow, Purple→Indigo), values fixed (e.g. Sarleon_Red 16711680→14356246), and **43 new color options** added (faction-themed: Noldor, Jatu, Heretics, KO colors, etc.) | **Tweak 13 c** / `mods\colfix`: greatly expanded player-kingdom color picker | **Certain** |
| 2726–2727 | "We_will_get_you_the_proper_supplies… (Baggage_Train_uses_2x_Various_Loot)": requirement & cost `2 → 1` | Baggage Train from quartermaster costs **1× Various Loot instead of 2×** (not in guide — PH custom) | Certain (effect) |
| 2920 | Potion of Janus consequence 10 ops → 5: removed "if drunk ≥3 times → only +1" branch | **Tweak 18 q** variant: Potion of Janus always grants the full +2 attribute points (no diminishing returns) | **Certain** |
| 3628 | arena-win dialog ops 3→4: added `call change_troop_renown(player, 100)` | **Tweak 7 h**: +100 renown per arena melee victory (config 42_1=100) | **Certain** |
| 3685–3688 | `dlga_prisoner_chat_sig3…` rewritten (old/new both match guide 1 e region) | **Tweak 1 e**: Aeldarian/Ithilrandir/Maltise don't leave Pendor after receiving their special equipment | **Certain** |
| 3690a3736 | 2 added dialog lines matching guide 1 d insertion | **Tweak 1 d**: take Maltise's Asp Throwing Axes / Wolfbode's axe when they're captured | **Certain** |
| 3699 | matches guide 3 g replacement | **Tweak 3 g**: unlock Sarleon & Ravenstern Armored Warhorses for your CKO | **Certain** |
| 3860–3862 | KO-equipment dialogs rewritten; "We_can't_sell_our_equipment." branch added; matches guide 3 e/3 f | **Tweak 3 e** (buy CKO equipment like any other KO), possibly with 3 f elements | Likely |
| 4114 | `dlga_order_blacksmith_1` (Alexios) ops 271→272; inserted `assign $upgrade_days 30` | **Tweak 2 b pt. 9**: every rune-item upgrade takes a flat **30 days** (config 58_1=30) | **Certain** |
| 4121 | +4 dialog lines around `dlga_order_quartermaster…`, using new `castle_horse_training_free*` states | **Tweak 2 d**: Quartermaster Kailin can train (free) horses | **Certain** |
| 4154a4205 | added line matching guide 15 r | **Tweak 15 r**: option to keep your fiefs when asking your king to release you from your oath | **Certain** |

## dialog_states.txt
- Appended `castle_horse_training_free`, `castle_horse_training_free1` → states for **Tweak 2 d** (Kailin horse training). *Certain.*

## variables.txt
- Appended `archer_reassign_division`, `form_options_overlay_26` → **Tweak 10 a/10 e** (battle-overlay archer reassignment / dynamic divisions). *Certain.*
- Appended `ambiance_channel` → **Tweak 21 m** (arena/tavern ambient-sound fix). *Certain.*

## quick_strings.txt
- Counter 3139 → 3141; appended `qstr_Reassign_archers_wit…` (**Tweak 10 a**) and `qstr_Not_enough_money.` (camp training menu). *Certain.*

## presentations.txt

| txt line | Change | Effect | Confidence |
|---|---|---|---|
| 229–230 | battle mini-map/order overlay presentations +ops; new side matches guide 10 a/10 e code | **Tweak 10 a** (reassign archers with empty ammo via overlay) + **Tweak 10 e** (divisions update dynamically) | **Certain** |
| 252 | prsnt_budget_report ops 661 → 634 (−27), exactly guide 12 c step 3 | **Tweak 12 c**: tax inefficiency system completely removed | **Certain** |
| 298, 300 | order-interface presentations +ops (matches 10 a) | **Tweak 10 a** order-screen part | **Certain** |

## triggers.txt

| txt line | Change | Effect | Confidence |
|---|---|---|---|
| 5 | merchant-gold regen: `if gold<3500 add rand(2000,3000)` → `if gold<50000 add rand(5000,10000)` | **Tweak 12 g**: much richer merchants (sell loot/prisoners without draining them) | **Certain** |
| 9 | same pattern ×3 for town merchants (`4500/400–800 → 50000/5000–10000`) + ransom brokers (`6000/500–900 → 50000/5000–10000`); the `ge 40000 → reset rand(100,200)` overflow branch kept | **Tweak 12 g** continued — all merchants & ransom brokers hold up to ~50k denars | **Certain** |

## simple_triggers.txt

| txt line | Change | Effect | Confidence |
|---|---|---|---|
| 22 | 200-hour trigger gutted to `0.000000 0` (it did `luck −1, min 25`) | **Tweak 21 b**: luck decay removed | **Certain** |
| 53 | town rent base `1200 → 2000` | **Tweak 12 a**: town rents raised (config 23_1=2000 likely) | Likely |
| 80 | 24-h trigger ops 130→135; inserted quest-log/notification code matching guide 7 b | **Tweak 7 b**: notification when a Noldor tournament is held at Elacrai | **Certain** |
| 89 | weekly renown decay `renown − renown/200` → `…/99999` | **Tweak 4 f**: renown decay effectively removed | **Certain** |
| 90 | book-reading progress per tick `+7 → +10` (item-slot accumulation to 1000) | Books read ~43% faster (possibly config 34_1=10) | Certain (effect) |
| 123 | 24-h trigger 426 → 67 tokens; logic that removed/handled an item tied to party template `…423556` deleted | **Tweak 18 k** (most consistent match): Ullr Vetr Manifest no longer disappears when Wolfbode is defeated | Likely |

## mission_templates.txt

| txt line(s) | Change | Effect | Confidence |
|---|---|---|---|
| 52, 57–63 | mst_town_default triggers 16→13: three ambiance-reset triggers deleted, `-19`/`-21` triggers replaced with `ambiance_channel` versions | **Tweak 21 m**: fix tavern/arena ambient sounds persisting after leaving | **Certain** |
| 1321–1343 | mst_arena_melee_fight: `-30`/`-29` triggers 2→7 ops + sound-channel stop calls | **Tweak 21 m** (arena part) | **Certain** |
| 557–559 deleted; 548→546+ adds `0.3`, `-58`, `-55`, `2.0`, `-25`, `-56` triggers (lead_charge 66→70 and others) | original dehorse triggers removed; new agent triggers: give sidearm Sword, handle dismounts, riding-skill bookkeeping, move-through-allies pass | **Tweak 10 c** (and 8 a-replacement): dehorsed/mounted-foot rework across field battle templates | **Certain** |
| 613–614→616, 646–647, 718–719, 753–754, 819–820, 880–881, 935–936, 1246–1247, 1744–1745 (and counters 1214: 33→32, 1720: 25→24) | the old two-trigger blunt-order implementation (`-71…` + `3.000000 3.000000…`) replaced by a single `-71` trigger calling new script `…063923` (= blunt_weapons_order) in ~9 templates | **Tweak 10 m**: reworked "use blunt weapons" order (knock-out captures work properly) | **Certain** |
| 494→491–492, 698a710, 733a745, 839+, 2419→2438–2439 … | added trigger `0.000000 1.000000 3.000000  10 71 1 20 …` — on keypress, player plays animation `…198842` + sound `…847332`, buffs nearby allies | **Tweak 10 q**: battlecry that inspires nearby troops (added to many battle templates) | **Certain** |
| 548/844/904 | key-24 trigger (`71 1 24`) grown 116→176 ops | **Tweak 10 g**: improved ammo-borrowing feature | **Certain** |
| 620–623 | mst_village_attack_bandits: `3 3 8208…→3 1 8208…`, `1 33558528…→3 …`, `1 4112…→3 …`; triggers 24→29 (10 c/10 q/shield triggers added) | **Tweak 8 j**: farmers/bandits spawn points swapped during village infestations (+10 c/q triggers) | **Certain** |
| 764→775+, 839→852+, 899→916+, 657→664+ | trigger-count +4 with the 10 c trigger set in more templates (incl. a `-25 … 5 2071…` agent-spawn variant) | **Tweak 10 c** rollout to village/bandit/night templates | **Certain** |
| 782d796 | deleted trigger `0.1 0.5 1e8 … call …063848` | **Tweak 9 b**: ammo no longer reduced during sally-outs | **Certain** |
| 1424–2612 (~28 hunks) | spawn records `N 4112 0 16 1 0` with N ∈ {1,11,21,31,41,51} renumbered to N+2 (`3,13,23,33,43,53`) across ~7 arena/tournament templates | Arena & tournament participant spawn entry points relocated by +2. **Not in the tweak guide** — most consistent with a bundled scene add-on (e.g. arena-overhaul style scenes, possibly the `ndmm` pack). Gameplay-visible effect: combatants spawn at different arena positions | Unknown (effect certain, source unidentified) |

## troops.txt

5 elite "unique-spawn army" troops had flag bit `0x80` (**tf_allways_fall_dead**) removed:
`trp_anaconda_knight` (also skin nibble 7→3), `trp_snake_priestess`, `trp_asp_vanguard`,
`trp_demonic_magnus`, and `trp_seeress` (large change `334496898→61867010`: 0x80 removed plus
upper guarantee-flag/skin bits altered).

Effect: these troops can now be **knocked unconscious and captured** instead of always dying
(and Seeress' appearance/equipment-guarantee flags changed). Not in the tweak guide → almost
certainly from a PH add-on pack (`mods\faces1` for the skin changes and/or a capture add-on).
*Effect certain; attribution unknown.*

---

## Applied-tweak checklist (by guide ID)

**Spawns/parties:** 1 d, 1 e, 1 i, 1 t, 1 w (party size), capture-always (1 a/1 b superset, 28_x=−100)
**Knighthood Orders:** 2 a, 2 b (flat 30-day upgrades), 2 d, 2 g (100%), 2 j, 2 l; CKO: 3 e(/3 f), 3 g
**Honor/renown:** 4 b (0 honor loss), 4 e (no renown cap), 4 f (no renown decay)
**Relations:** 5 f/5 g (no fief-envy), 5 k-like (+5 release relation)
**Tournaments/arena:** 7 a (+Qualis 100%), 7 b, 7 f (renown bets), prize 5000, 7 h (+100 renown)
**Battles:** 8 j, 8 k, 9 b, 9 h, 10 a, 10 c, 10 e, 10 g, 10 k (crouch), 10 m, 10 q, 10 u, (10 f?)
**Loot:** 11 a, 11 c
**Economy:** 12 a (rents 2000), 12 c (no tax inefficiency), 12 e (9%/Leadership wages), 12 g (rich merchants)
**Kingdom:** 13 c (colors), 13 h, 13 v (fast building), 15 a, 15 i, 15 q, 15 r
**Companions/troops:** 16 o, 17 e, camp XP training (17 c variant)
**Items/misc:** 18 k (likely), 18 q (Janus potion), faster book reading, baggage-train cost 1, 21 b (luck), 21 m (sounds), XP multipliers ×4/×3, capturable elite Snake-Cult troops, arena spawn relocation (unidentified)

Total: **~60 distinct tweaks** — matching the 60 checked boxes in `tweakch_395`.
