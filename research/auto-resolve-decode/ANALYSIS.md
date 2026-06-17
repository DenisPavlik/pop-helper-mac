# Auto-resolve (autocalc) reverse engineering — PoP 3.9.5

Goal: understand and tune Warband/PoP "auto-resolve" battles (the
"Order your troops to attack without you" option) so a strong army stops
taking absurd casualties against trash enemies.

## How the bytecode was decoded

`scripts.txt` stores each script as one line of integer tokens:
`<num_ops> (op nargs arg1..argN)*`. Operands are tagged 64-bit values
(`tag << 56 | index`); tags: 1 reg, 2 global var, 3 string, 5 troop,
6 faction, 9 party, 13 script, 17 local var, 19 skill, 22 quick-string.
Conditional ops carry `neg = 0x80000000` / `this_or_next = 0x40000000`.

- `decode.py` — turns a script body into readable `op(args)` lines using
  `header_operations.py` (fetched from the Persistent-Kingdoms module system,
  opcode table is identical to stock Warband 1.143/1.153).
- `extract_ops.py` — slices the exact raw-token spans of the tunable ops and
  proves they are unique (literal + wildcarded) in both the pristine and live
  `scripts.txt`.

Decoded bodies are saved next to this file.

## The two auto-resolve engines

1. **`simulate_battle_with_agents_aux`** (script idx 325, wrapper idx 324) —
   a real agent-based simulation, called from `mission_templates.txt` (the
   in-scene "fast-forward / speed up the battle" feature). Fully scriptable.
   Per-swing hit chance:

   ```
   hit_chance = base + (attacker_level − target_level) / 5      # op 75: val_div(:20, 5)
   swings    ≈ 2 × 18000/(distance+3000) × atk_class / tgt_class
   ```

   The `/5` is why low-tier troops still hurt elites: the level gap barely
   moves the hit chance. A "quality matters" fix here = change `/5` to `/2`
   or `/1`.

2. **`game_event_simulate_battle`** (script idx 10) — called **by the engine
   itself by name** (no `.txt` reference). This is the campaign auto-resolve:
   off-map AI-vs-AI battles **and** the player's "attack without you" (the menu
   option requires battle advantage ≥ 4 to appear). Casualties are applied by
   the engine op `inflict_casualties_to_party_group` (a black box); the script
   only computes the *strength* fed into it.

`calculate_battle_advantage` (idx 10/447): advantage scales with the
strength ratio **and ±30 per Tactics point** (skill 15), then /100 — so
Tactics is a strong, legitimate lever even without any tweak.

## Casualty math in `game_event_simulate_battle` (ops 35–98)

```
:11 = your-side power,  :12 = your count     (script 634)
:13 = enemy power,      :14 = enemy count
:15 (enemy losses) = :14 × :11 / 100         # enemy_count × your_power
:16 (your  losses) = :12 × :13 / 100         # your_count  × enemy_power
if both sides' strength < 180:  :15,:16 /= 30      # ops 69-70  ("lowdiv")
else:                            :15,:16 /= 90      # ops 72-73  ("highdiv")
# NORMALISE (ops 76-82): if max(:15,:16) > 100 → scale both so max = 100
if night: :15,:16 /= 2                              # ops 86-87
:15 = max(:15, 5);  :16 = max(:16, 5)               # ops 89-90  ("floor")
inflict_casualties_to_party_group(enemy, :15)       # op 92
inflict_casualties_to_party_group(you,   :16)       # op 98
```

**Core flaw:** your losses depend on `your_count × enemy_power` only — your
own troop *quality/power* never reduces your losses. A big trash horde still
bleeds you proportionally to your headcount. (Bannerlord fixed exactly this.)

### Which lever actually works — and why

- **Divisors (30 / 90):** in the ratio `:16/:15` the divisor *cancels*, and the
  normalisation step rescales the max back to 100. So whenever normalisation
  triggers (medium/large battles) changing the divisor is **self-cancelling**.
  Not a reliable lever. Do **not** expose it as if it helps.
- **Floor (`val_max …, 5`):** on the **winning** side the loss value is large
  (≫5) so this floor never binds there; it binds only on the side taking light
  losses — i.e. **you**, when you dominate. Lowering 5 → 1/0 makes lopsided
  auto-resolves cost you ~0 troops, and **cannot flip a win** (enemy losses are
  untouched). This is the safe, correct first lever → shipped as tweak
  `auto-resolve-min-casualties`.
- **Normalisation cap (100):** governs absolute losses in large battles, but
  lowering it also lowers enemy losses, which may force extra resolve passes —
  risk depends on whether the engine re-runs the sim (one-shot for small
  fights, iterative for large). Needs in-game measurement before exposing.
- **Strength ratio (the real "Bannerlord" fix):** insert, right before the
  player's `inflict_casualties_to_party_group`, a scaling of *only the player's*
  losses by `enemy_strength / your_strength` (player side = `party:0` =
  `p_main_party`; powers `:11`/`:13` already computed). Deterministic
  "dominate ⇒ ~0 losses", leaves enemy losses & win logic intact. Structural
  (op insert + counter bump 576→+N). Phase 2.

## Tunable ops — exact bytes (verified unique in pristine & live)

```
floor block (ops 89-90):
  2111 2 1224979098644774928 5 2111 2 1224979098644774927 5
div block   (ops 66-74):
  4 0 2147483678 2 1224979098644774928 180 2147483678 2 1224979098644774927 180
  2108 2 1224979098644774928 30 2108 2 1224979098644774927 30 5 0
  2108 2 1224979098644774928 90 2108 2 1224979098644774927 90 3 0
```

(`2111`=val_max, `2108`=val_div, `:15`=local 1224979098644774927,
`:16`=local 1224979098644774928.)

## Status

- **Phase 1 (shipped):** `auto-resolve-min-casualties` — floor 5 → 1.
  Safe, targets the complaint, and is *diagnostic*: if losses drop, the player's
  fights are floor-bound (small); if not, they are in the normalised regime and
  Phase 2 is required.
- **Phase 2 (planned):** strength-ratio scaling of the player's losses
  (deterministic quality-aware fix). Optionally the agent-sim `/5 → /2`.
