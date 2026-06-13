# PoP Helper for macOS

A native macOS app (SwiftUI) for managing gameplay tweaks of the Mount & Blade: Warband mod **Prophesy of Pendor 3.9.5** — a spiritual successor to the Windows-only "PoP Helper" by Rumata.

## What it does

PoP tweaks are plain-text edits to the mod's module files (`menus.txt`, `scripts.txt`, `simple_triggers.txt`, `troops.txt`, …). This app:

- Shows a catalog of known tweaks with checkboxes and tunable values
  (e.g. unique spawns can't escape after battle, max Qualis Gem chance at
  Noldor tournaments, recruit Noldor troops, bigger tournament rewards)
- Applies / reverts tweaks by patching the module files
- **Reset to Defaults** — restores every module file to vanilla 3.9.5, undoing
  all tweaks at once (known or not) for a clean slate
- Backs up module files automatically: a full **initial snapshot** the first
  time the app sees a mod folder, plus a safety backup before every change
- Restores from any backup
- Bilingual UI: Ukrainian / English

## Paths

- Mod folder: `~/Library/Application Support/Steam/steamapps/common/MountBlade Warband/Modules/Prophesy of Pendor V3.9.5`
- Savegames: `~/Library/Application Support/Mount and Blade Warband Savegames/Prophesy of Pendor`

## Project layout

- `docs/tweak-db-format.md` — the `tweaks.json` schema (schemaVersion 1)
- `research/` — reverse-engineering artifacts:
  - `PH_config.ini` — the original PoP Helper settings recovered from the mod folder
  - `diffs/` — diffs between the pristine 3.9.5 files (from PoP Helper's own backup) and the tweaked files, i.e. ground truth for what each tweak changes
  - `tweak-catalog.md` — catalog of known tweaks compiled from the PoP wiki and Steam guides
  - `applied-tweaks-analysis.md` — interpretation of the diffs / PH_config
  - `validate_tweaks.py` — validates `tweaks.json` against the pristine files; `--status` reports applied/not/conflict against the live mod
- `PoPHelper/Sources/` — the SwiftUI app:
  - `Models/TweakModels.swift` — DB model types
  - `Engine/TweakEngine.swift` — pure search/replace apply/revert/status engine
  - `Engine/ModManager.swift` — locating the mod, file IO (ISO-Latin-1, byte-exact), timestamped backups
  - `AppState.swift`, `L10n.swift`, `UI/` — SwiftUI app, bilingual strings
  - `SelfTest.swift`, `CLI.swift` — headless `--self-test` and `--status` entry points
- `PoPHelper/Resources/tweaks.json` — the tweak database

## Building & running

Command Line Tools only (no Xcode required):

```
swift build                         # build
swift run PoPHelper                 # launch the GUI
swift run PoPHelper --self-test     # run the engine self-tests (no XCTest needed)
swift run PoPHelper --status        # report each tweak's state against the live mod
python3 research/validate_tweaks.py # validate tweaks.json against pristine files
```

## Status / roadmap

- [x] Locate mod, recover PH_config.ini and pristine-file backups
- [x] Extract diffs of previously applied tweaks
- [x] Compile tweak catalog (research agents) — 293 tweaks in `research/tweak-catalog.md`
- [x] Reverse-engineer previously applied tweaks — `research/applied-tweaks-analysis.md` (~60 identified)
- [x] Design tweak database format — `docs/tweak-db-format.md`; 10-tweak starter DB validated
- [x] Tweak engine (apply / revert / status) + backups; self-tests green; cross-checked against the live mod
- [x] Reset to Defaults + automatic initial/safety backups (pristine baseline imported from PoP Helper's pre-tweak backup)
- [x] Category-organized SwiftUI UI — sidebar of categories, compact checkbox list, search
- [x] Grow the DB — **49 tweaks** across 13 categories, all validated against pristine files
- [x] Verify apply/revert end-to-end — `swift run PoPHelper --verify-apply` round-trips every tweak on the pristine baseline (49/49, no disk writes)
- [x] Cosmetic pack manager — install/uninstall PoP Helper's add-on packs (female
  faces, crosshair, UI skin, fonts, arena, …) with backups + module.ini handling;
  `research/extract_rcc.py` pulls them from PoP Helper's Qt `.rcc` files (assets
  stay local, not in git)
- [ ] Visually verify apply / revert / reset / packs through the GUI + in-game
- [ ] Keep growing the tweak DB toward fuller catalog coverage (293 known; mine `tweaks.sl3`)
- [ ] Bundle as a downloadable `.app` (GitHub Release)
