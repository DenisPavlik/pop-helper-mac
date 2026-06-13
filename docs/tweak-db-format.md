# Tweak database format (schemaVersion 1)

`PoPHelper/Resources/tweaks.json` is the single source of truth the app reads.
It encodes each tweak as literal search/replace operations on the mod's .txt
files, with tunable parameters expressed as `{key}` placeholders.

## Top level

```json
{
  "schemaVersion": 1,
  "gameVersion": "3.9.5",
  "tweaks": [ Tweak, ... ]
}
```

## Tweak

```json
{
  "id": "unique-spawns-always-captured",        // kebab-case, stable
  "name":        { "en": "...", "uk": "..." },
  "description": { "en": "...", "uk": "..." },
  "category": "spawns",                          // spawns | tournaments | noldor | companions | prisoners | economy | other
  "wikiRef": "Tweak 1 a",                        // reference into research/tweak-catalog.md
  "params": [ Param, ... ],                      // may be empty
  "operations": [ Operation, ... ]
}
```

## Param

```json
{
  "key": "threshold",                 // used as {threshold} in templates
  "name": { "en": "...", "uk": "..." },
  "originalValue": 60,                // value in the pristine file
  "defaultValue": -100,               // what the app suggests when enabling
  "min": -100,
  "max": 150,
  "presets": [                        // optional, shown as quick choices
    { "value": -100, "label": { "en": "Always captured", "uk": "Завжди в полоні" } }
  ]
}
```

All params are integers.

## Operation

```json
{
  "file": "menus.txt",
  "original": "2147483678 2 1224979098644774956 60",       // literal, verbatim from pristine file
  "replacement": "2147483678 2 1224979098644774956 {threshold}",
  "occurrence": "all",        // "all" | [1] | [2] | [1,2] — 1-based indices among matches of `original`
  "expectedCount": 1,         // how many times `original` appears in the pristine file (validation + status detection)
  "structural": false         // optional, default false; see below
}

`structural: true` marks operations whose replacement is a rewritten block
rather than the original with different numbers (e.g. full script-body
overhauls). For value-only operations (`structural` absent/false), rendering
`replacement` with each param's `originalValue` must reproduce `original`
byte-exactly; for structural operations that invariant does not hold and each
param's `originalValue` is instead the wiki's stock value for that slot of the
replacement body.
```

Rules:

- `original` is an exact substring of the pristine file (no placeholders, no
  regex). Long script-body replacements are fine — it's just a long literal.
- `replacement` is the same text with tunable numbers replaced by `{key}`
  placeholders. Every placeholder must reference a declared param.
- Engine semantics:
  - **status detection** (per tweak, all operations must agree):
    - every `original` found `expectedCount` times → **not applied**
    - else, regex built from `replacement` (placeholders → `(-?\d+)`) matches →
      **applied** (current param values are read from the capture groups)
    - else → **conflict** (file was hand-edited or another tool changed it;
      app refuses to touch it and offers restore-from-backup)
  - **apply**: replace the selected occurrences of `original` with
    `replacement` rendered using the chosen param values
  - **revert**: replace regex matches of the rendered `replacement` back with
    `original`
- A tweak with no tunable values still has `replacement` (with hardcoded new
  numbers) and `params: []`.

## Out of scope for schemaVersion 1

- quick_strings.txt "append a line + bump the counter" style edits
- edits to binary assets (BRF/DDS)
- positional instructions ("change the 5th number") — must be converted to
  literal search/replace against the pristine 3.9.5 files before entering the DB
