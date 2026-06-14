import Foundation

/// Headless status report run by the Swift engine against the real mod folder:
///     swift run PoPHelper --status
/// Mirrors `research/validate_tweaks.py --status`; used to cross-check that the
/// engine agrees with the Python validator on real files.
enum CLI {
    static func statusReport() -> Bool {
        let manager = ModManager()
        guard manager.modFolderExists else {
            print("Mod folder not found: \(manager.modFolder.path)")
            return false
        }
        do {
            let db = try TweakDatabase.load()
            let fileNames = Set(db.tweaks.flatMap { $0.operations.map(\.file) })
            let files = try manager.readFiles(named: fileNames)
            let byteFiles = files.mapValues { Array($0.utf8) }   // convert once for the whole batch
            print("Status report against: \(manager.modFolder.path)")
            let width = db.tweaks.map(\.id.count).max() ?? 0
            for tweak in db.tweaks {
                let id = tweak.id.padding(toLength: width + 2, withPad: " ", startingAt: 0)
                switch TweakEngine.status(of: tweak, byteFiles: byteFiles) {
                case .notApplied:
                    print("  \(id) not applied")
                case .applied(let values):
                    let detail = values.isEmpty
                        ? "applied"
                        : "applied " + values.sorted { $0.key < $1.key }
                            .map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                    print("  \(id) \(detail)")
                case .conflict(let why):
                    print("  \(id) conflict (\(why))")
                }
            }
            return true
        } catch {
            print("Error: \(error.localizedDescription)")
            return false
        }
    }

    /// Read-only: checks every pack in packs.json is present in the local library and
    /// that each file mapping resolves to real source file(s). `swift run PoPHelper --verify-packs`
    static func verifyPacks() -> Bool {
        let manager = ModManager()
        let pm = PackManager(modFolder: manager.modFolder)
        do {
            let db = try PackDatabase.load()
            let installed = pm.loadState()
            var ok = true
            print("Cosmetic packs (library: \(pm.packsLibrary.path))\n")
            for pack in db.packs {
                let avail = pm.isAvailable(pack)
                let inst = installed[pack.id] != nil
                let opts = pack.options?.count ?? 0
                var detail = avail ? "available" : "MISSING from library"
                if !avail { ok = false }
                if pack.kind == .choice { detail += ", \(opts) options" }
                if inst { detail += ", INSTALLED(\(installed[pack.id]?.optionId ?? "-"))" }
                print("  \(pack.id.padding(toLength: 18, withPad: " ", startingAt: 0)) \(detail)")
            }
            print(ok ? "\nRESULT: all packs available." : "\nRESULT: some packs missing from the local library.")
            return ok
        } catch {
            print("Error: \(error.localizedDescription)")
            return false
        }
    }

    /// Dry run: against the real mod files (read-only, nothing is written), apply every
    /// not-applied tweak in memory and revert every applied one, checking the resulting
    /// status. Verifies the apply/revert engine on real data without touching the mod.
    static func verifyApply() -> Bool {
        let live = ModManager()
        guard let pristineDir = live.detectPoPHelperPristineBackup()
                ?? (live.hasPristineBaseline ? live.pristineStore : nil) else {
            print("No pristine baseline found to verify against.")
            return false
        }
        let base = ModManager(modFolder: pristineDir)
        do {
            let db = try TweakDatabase.load()
            let fileNames = Set(db.tweaks.flatMap { $0.operations.map(\.file) })
            let files = try base.readFiles(named: fileNames)
            var applyOK = 0, applyFail = 0, revertOK = 0, revertFail = 0, statusFail = 0
            var noopDefaults: [String] = []
            var failures: [String] = []

            // Force each param to differ from vanilla so apply yields a detectable
            // change — this tests the engine, separate from default-value tuning.
            func testValues(_ tweak: Tweak) -> [String: Int] {
                var v: [String: Int] = [:]
                for p in tweak.params {
                    if p.defaultValue != p.originalValue {
                        v[p.key] = p.defaultValue
                    } else {
                        let hi = p.max ?? Int(Int32.max)
                        let lo = p.min ?? Int(Int32.min)
                        v[p.key] = p.originalValue < hi ? p.originalValue + 1
                            : (p.originalValue > lo ? p.originalValue - 1 : p.originalValue)
                    }
                }
                return v
            }

            for tweak in db.tweaks {
                // On a pristine baseline every tweak must read as not-applied.
                if case .notApplied = TweakEngine.status(of: tweak, files: files) {} else {
                    statusFail += 1
                    failures.append("status \(tweak.id): not 'notApplied' on pristine baseline")
                }
                var copy = files
                do {
                    try TweakEngine.apply(tweak, values: testValues(tweak), to: &copy)
                    if case .applied = TweakEngine.status(of: tweak, files: copy) {
                        applyOK += 1
                        var back = copy
                        try TweakEngine.revert(tweak, in: &back)
                        if case .notApplied = TweakEngine.status(of: tweak, files: back), back == files {
                            revertOK += 1
                        } else {
                            revertFail += 1
                            failures.append("revert \(tweak.id): did not restore pristine byte-exact")
                        }
                    } else {
                        applyFail += 1
                        failures.append("apply \(tweak.id): status not 'applied' afterwards")
                    }
                } catch {
                    applyFail += 1
                    failures.append("apply \(tweak.id): \(error.localizedDescription)")
                }
                // Flag tweaks whose DEFAULT values change nothing when enabled.
                if !tweak.params.isEmpty {
                    var d = files
                    let defs = Dictionary(uniqueKeysWithValues: tweak.params.map { ($0.key, $0.defaultValue) })
                    if (try? TweakEngine.apply(tweak, values: defs, to: &d)) != nil, d == files {
                        noopDefaults.append(tweak.id)
                    }
                }
            }

            print("Comprehensive apply/revert against pristine baseline")
            print("(\(pristineDir.lastPathComponent); in-memory only — no files written)\n")
            print("  tweaks:    \(db.tweaks.count)")
            print("  apply  ok: \(applyOK), failed: \(applyFail)")
            print("  revert ok: \(revertOK), failed: \(revertFail)")
            print("  status on pristine wrong: \(statusFail)")
            for f in failures { print("  ✗ \(f)") }
            if !noopDefaults.isEmpty {
                print("\n  note — \(noopDefaults.count) tunable-knob tweak(s) whose DEFAULT == vanilla")
                print("  (toggling does nothing until a value is changed): \(noopDefaults.joined(separator: ", "))")
            }
            let ok = applyFail == 0 && revertFail == 0 && statusFail == 0
            print(ok ? "\nRESULT: every tweak applies and reverts cleanly on pristine."
                     : "\nRESULT: failures found.")
            return ok
        } catch {
            print("Error: \(error.localizedDescription)")
            return false
        }
    }

    /// Applies the given tweak ids (at their default values) to the LIVE mod files and
    /// writes them back. Drives the automated in-game load-test loop:
    ///     swift run PoPHelper --apply qualis-gem-chance-noldor-tournament,tournament-rewards
    /// Prints one line per tweak (`APPLIED <id>` / `NOTAPPLICABLE <id>` / `ERROR ...`) and a
    /// SUMMARY line. A tweak whose pristine pattern isn't present on the live files (e.g. a
    /// hand-edited or already-variant section) is NOTAPPLICABLE — skipped, not an error.
    /// Exit code: 0 = at least one tweak applied & written, 3 = none applicable, 1 = hard error.
    static func applyTweaks(ids: [String]) -> Int32 {
        let manager = ModManager()
        guard manager.modFolderExists else {
            print("Mod folder not found: \(manager.modFolder.path)")
            return 1
        }
        do {
            let db = try TweakDatabase.load()
            let byId = Dictionary(uniqueKeysWithValues: db.tweaks.map { ($0.id, $0) })
            let unknown = ids.filter { byId[$0] == nil }
            if !unknown.isEmpty {
                print("UNKNOWN \(unknown.joined(separator: ", "))")
                return 1
            }
            let tweaks = ids.compactMap { byId[$0] }
            let fileNames = Set(tweaks.flatMap { $0.operations.map(\.file) })
            var files = try manager.readFiles(named: fileNames)
            var applied: [String] = []
            var notApplicable: [String] = []
            for tweak in tweaks {
                let defs = Dictionary(uniqueKeysWithValues: tweak.params.map { ($0.key, $0.defaultValue) })
                var trial = files            // apply to a copy; commit only on full success
                do {
                    try TweakEngine.apply(tweak, values: defs, to: &trial)
                    files = trial
                    applied.append(tweak.id)
                    print("APPLIED \(tweak.id)")
                } catch let e as TweakEngineError {
                    if case .notInExpectedState = e {
                        notApplicable.append(tweak.id)
                        print("NOTAPPLICABLE \(tweak.id)")
                    } else {
                        print("ERROR \(tweak.id): \(e.localizedDescription)")
                        return 1
                    }
                }
            }
            if !applied.isEmpty { try manager.write(files: files) }
            print("SUMMARY applied=\(applied.count) notApplicable=\(notApplicable.count)")
            return applied.isEmpty ? 3 : 0
        } catch {
            print("Error: \(error.localizedDescription)")
            return 1
        }
    }
}
