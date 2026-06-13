# PoP Helper for macOS

A native macOS app (SwiftUI) for managing gameplay tweaks of the Mount & Blade: Warband mod **Prophesy of Pendor 3.9.5** — a spiritual successor to the Windows-only "PoP Helper" by Rumata.

## What it does

PoP tweaks are plain-text edits to the mod's module files (`menus.txt`, `scripts.txt`, `simple_triggers.txt`, `troops.txt`, …). This app:

- Shows a catalog of known tweaks with checkboxes and tunable values
  (e.g. unique spawns can't escape after battle, max Qualis Gem chance at
  Noldor tournaments, recruit Noldor troops, bigger tournament rewards)
- Applies / reverts tweaks by patching the module files
- Backs up module files and savegames automatically before any change
- Restores from backup (including broken-save recovery)
- Bilingual UI: Ukrainian / English

## Paths

- Mod folder: `~/Library/Application Support/Steam/steamapps/common/MountBlade Warband/Modules/Prophesy of Pendor V3.9.5`
- Savegames: `~/Library/Application Support/Mount and Blade Warband Savegames/Prophesy of Pendor`

## Project layout

- `research/` — reverse-engineering artifacts:
  - `PH_config.ini` — the original PoP Helper settings recovered from the mod folder
  - `diffs/` — diffs between the pristine 3.9.5 files (from PoP Helper's own backup) and the tweaked files, i.e. ground truth for what each tweak changes
  - `tweak-catalog.md` — catalog of known tweaks compiled from the PoP wiki and Steam guides
  - `applied-tweaks-analysis.md` — interpretation of the diffs / PH_config
- `PoPHelper/` — the SwiftUI app (Swift Package, builds to a .app)

## Status / roadmap

- [x] Locate mod, recover PH_config.ini and pristine-file backups
- [x] Extract diffs of previously applied tweaks
- [x] Compile tweak catalog (research agents) — 293 tweaks in `research/tweak-catalog.md`
- [x] Reverse-engineer previously applied tweaks — `research/applied-tweaks-analysis.md` (~60 identified)
- [ ] Design tweak database format (JSON: search/replace patterns + parameters)
- [ ] SwiftUI app: tweak list UI, apply/revert engine, backup manager
- [ ] Bundle as .app
