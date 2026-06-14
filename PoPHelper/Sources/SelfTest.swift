import Foundation

/// Lightweight in-process test harness so the engine can be verified without
/// Xcode/XCTest (the dev machine has Command Line Tools only). Run with:
///     swift run PoPHelper --self-test
enum SelfTest {

    private final class Recorder {
        var failures: [String] = []
        var checks = 0

        func expect(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String) {
            checks += 1
            if !condition() { failures.append(message()) }
        }

        func expectEqual<T: Equatable>(_ a: T, _ b: T, _ message: @autoclosure () -> String) {
            checks += 1
            if a != b { failures.append("\(message()) — got \(a), expected \(b)") }
        }

        func expectThrows(_ message: @autoclosure () -> String, _ body: () throws -> Void) {
            checks += 1
            do { try body(); failures.append("\(message()) — expected throw, none thrown") }
            catch { /* expected */ }
        }

        func expectNoThrow(_ message: @autoclosure () -> String, _ body: () throws -> Void) {
            checks += 1
            do { try body() } catch { failures.append("\(message()) — unexpected throw: \(error)") }
        }
    }

    // MARK: Fixtures

    private static func tweak(
        id: String = "t",
        params: [TweakParam] = [],
        operations: [TweakOperation]
    ) -> Tweak {
        Tweak(
            id: id,
            name: LocalizedText(en: id, uk: id),
            description: LocalizedText(en: "", uk: ""),
            category: "other",
            wikiRef: nil,
            params: params,
            operations: operations)
    }

    private static let thresholdParam = TweakParam(
        key: "threshold",
        name: LocalizedText(en: "Threshold", uk: "Поріг"),
        originalValue: 60, defaultValue: -100, min: -100, max: 150, presets: nil)

    // MARK: Run

    /// Returns true if all checks passed.
    static func run() -> Bool {
        let r = Recorder()

        templates(r)
        applyRevertRoundTrip(r)
        multiOccurrenceAll(r)
        selectiveOccurrence(r)
        noParamFullReplacement(r)
        conflictDetection(r)
        applyGuards(r)
        occurrenceDecoding(r)
        resetAndBackups(r)
        packManager(r)
        gameConfig(r)
        bundledDatabase(r)
        bundledPackDatabase(r)

        if r.failures.isEmpty {
            print("✅ self-test passed — \(r.checks) checks")
            return true
        } else {
            print("❌ self-test FAILED — \(r.failures.count)/\(r.checks) checks failed:")
            for f in r.failures { print("   • \(f)") }
            return false
        }
    }

    // MARK: Cases

    private static func templates(_ r: Recorder) {
        let keys: Set<String> = ["threshold"]
        r.expectEqual(TweakEngine.placeholderKeys(in: "a {threshold} b {threshold}", declaredKeys: keys),
                      ["threshold", "threshold"], "placeholderKeys repeated")
        r.expectNoThrow("render basic") {
            r.expectEqual(try TweakEngine.render("a {threshold} c {threshold}", values: ["threshold": -100], declaredKeys: keys),
                          "a -100 c -100", "render basic")
        }
        // Game register tokens are literal, not params.
        r.expectEqual(TweakEngine.placeholderKeys(in: "say {s9} reg {reg9} and {threshold}", declaredKeys: keys),
                      ["threshold"], "undeclared braces ignored")
        r.expectNoThrow("render keeps registers") {
            r.expectEqual(try TweakEngine.render("say {s9} reg {reg9} and {threshold}", values: ["threshold": 5], declaredKeys: keys),
                          "say {s9} reg {reg9} and 5", "render keeps registers")
        }
        r.expectThrows("render missing value") {
            _ = try TweakEngine.render("{x}", values: [:], declaredKeys: ["x"])
        }
    }

    private static func applyRevertRoundTrip(_ r: Recorder) {
        let op = TweakOperation(
            file: "menus.txt",
            original: "2147483678 2 1224979098644774956 60",
            replacement: "2147483678 2 1224979098644774956 {threshold}",
            occurrence: .all, expectedCount: 1)
        let t = tweak(params: [thresholdParam], operations: [op])
        let pristine = "head 2147483678 2 1224979098644774956 60 tail"
        var files = ["menus.txt": pristine]

        r.expectEqual(TweakEngine.status(of: t, files: files), .notApplied, "status pristine")
        r.expectNoThrow("apply") { try TweakEngine.apply(t, values: ["threshold": -100], to: &files) }
        r.expectEqual(files["menus.txt"], "head 2147483678 2 1224979098644774956 -100 tail", "apply result")
        r.expectEqual(TweakEngine.status(of: t, files: files), .applied(values: ["threshold": -100]), "status applied")
        r.expectNoThrow("revert") { try TweakEngine.revert(t, in: &files) }
        r.expectEqual(files["menus.txt"], pristine, "revert restores pristine")
    }

    private static func multiOccurrenceAll(_ r: Recorder) {
        let op = TweakOperation(
            file: "scripts.txt", original: "4 0 30 2 X 60", replacement: "4 0 30 2 X {threshold}",
            occurrence: .all, expectedCount: 2)
        let t = tweak(params: [thresholdParam], operations: [op])
        var files = ["scripts.txt": "4 0 30 2 X 60 mid 4 0 30 2 X 60 end"]
        r.expectNoThrow("apply all") { try TweakEngine.apply(t, values: ["threshold": 0], to: &files) }
        r.expectEqual(files["scripts.txt"], "4 0 30 2 X 0 mid 4 0 30 2 X 0 end", "apply all result")
        r.expectEqual(TweakEngine.status(of: t, files: files), .applied(values: ["threshold": 0]), "status all applied")
        r.expectNoThrow("revert all") { try TweakEngine.revert(t, in: &files) }
        r.expectEqual(TweakEngine.status(of: t, files: files), .notApplied, "status all reverted")
    }

    private static func selectiveOccurrence(_ r: Recorder) {
        let op = TweakOperation(
            file: "f.txt", original: "AA 7 BB", replacement: "AA {v} BB",
            occurrence: .indices([2]), expectedCount: 2)
        let param = TweakParam(key: "v", name: LocalizedText(en: "v", uk: "v"),
                               originalValue: 7, defaultValue: 99, min: nil, max: nil, presets: nil)
        let t = tweak(params: [param], operations: [op])
        var files = ["f.txt": "AA 7 BB | AA 7 BB"]
        r.expectNoThrow("apply selective") { try TweakEngine.apply(t, values: ["v": 99], to: &files) }
        r.expectEqual(files["f.txt"], "AA 7 BB | AA 99 BB", "apply selective result")
        r.expectEqual(TweakEngine.status(of: t, files: files), .applied(values: ["v": 99]), "status selective")
        r.expectNoThrow("revert selective") { try TweakEngine.revert(t, in: &files) }
        r.expectEqual(files["f.txt"], "AA 7 BB | AA 7 BB", "revert selective result")
    }

    private static func noParamFullReplacement(_ r: Recorder) {
        let op = TweakOperation(
            file: "f.txt", original: "old block 1 2 3", replacement: "new block 4 5 6",
            occurrence: .all, expectedCount: 1)
        let t = tweak(operations: [op])
        var files = ["f.txt": "pre old block 1 2 3 post"]
        r.expectNoThrow("apply full") { try TweakEngine.apply(t, values: [:], to: &files) }
        r.expectEqual(files["f.txt"], "pre new block 4 5 6 post", "apply full result")
        r.expectEqual(TweakEngine.status(of: t, files: files), .applied(values: [:]), "status full applied")
        r.expectNoThrow("revert full") { try TweakEngine.revert(t, in: &files) }
        r.expectEqual(files["f.txt"], "pre old block 1 2 3 post", "revert full result")
    }

    private static func conflictDetection(_ r: Recorder) {
        // Vanilla pattern entirely gone & not our applied form → appliedExternally (the original
        // PoP Helper already tweaked this spot in its own variant), NOT a hard conflict.
        let op = TweakOperation(
            file: "f.txt", original: "needle 60", replacement: "needle {threshold}",
            occurrence: .all, expectedCount: 1)
        let t = tweak(params: [thresholdParam], operations: [op])
        if case .appliedExternally = TweakEngine.status(of: t, files: ["f.txt": "something else"]) {} else {
            r.failures.append("expected appliedExternally when vanilla pattern fully gone"); r.checks += 1
        }

        // Structural op (no params), vanilla block replaced by an unknown form → appliedExternally.
        let opS = TweakOperation(file: "f.txt", original: "old block 1 2 3", replacement: "new block 4 5 6",
                                 occurrence: .all, expectedCount: 1)
        let tS = tweak(operations: [opS])
        if case .appliedExternally = TweakEngine.status(of: tS, files: ["f.txt": "pre someone elses variant post"]) {} else {
            r.failures.append("expected appliedExternally for structural op with unknown variant"); r.checks += 1
        }

        // Genuine partial/ambiguous state (1 of 2 vanilla occurrences, none applied) → conflict.
        let opP = TweakOperation(file: "f.txt", original: "X 1", replacement: "X 2",
                                 occurrence: .all, expectedCount: 2)
        let tP = tweak(operations: [opP])
        if case .conflict = TweakEngine.status(of: tP, files: ["f.txt": "X 1 only once"]) {} else {
            r.failures.append("expected conflict when partial occurrences (1 of 2)"); r.checks += 1
        }

        // Multi-op: one knob tweaked, one left at its vanilla value → applied (NOT conflict).
        let opA = TweakOperation(file: "a.txt", original: "X 1", replacement: "X 2", occurrence: .all, expectedCount: 1)
        let opB = TweakOperation(file: "b.txt", original: "Y 1", replacement: "Y 2", occurrence: .all, expectedCount: 1)
        let t2 = tweak(operations: [opA, opB])
        if case .applied = TweakEngine.status(of: t2, files: ["a.txt": "X 2", "b.txt": "Y 1"]) {} else {
            r.failures.append("expected applied when one op tweaked, one at vanilla"); r.checks += 1
        }
    }

    private static func applyGuards(_ r: Recorder) {
        let op = TweakOperation(file: "f.txt", original: "X 1", replacement: "X 2", occurrence: .all, expectedCount: 2)
        let t = tweak(operations: [op])
        var files = ["f.txt": "X 1"]   // only 1 occurrence, expected 2
        r.expectThrows("apply refuses unexpected state") { try TweakEngine.apply(t, values: [:], to: &files) }
        r.expectEqual(files["f.txt"], "X 1", "apply left file unchanged on guard")
    }

    private static func occurrenceDecoding(_ r: Recorder) {
        let json = """
        [{"file":"f","original":"a","replacement":"b","occurrence":"all","expectedCount":1},
         {"file":"f","original":"a","replacement":"b","occurrence":[1,3],"expectedCount":3}]
        """
        r.expectNoThrow("decode occurrence") {
            let ops = try JSONDecoder().decode([TweakOperation].self, from: Data(json.utf8))
            r.expectEqual(ops[0].occurrence, .all, "occurrence all")
            r.expectEqual(ops[1].occurrence, .indices([1, 3]), "occurrence indices")
        }
    }

    private static func resetAndBackups(_ r: Recorder) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("pophelper-selftest-\(getpid())")
        try? fm.removeItem(at: root)
        defer { try? fm.removeItem(at: root) }

        func makeDir(_ url: URL) throws { try fm.createDirectory(at: url, withIntermediateDirectories: true) }
        func write(_ text: String, _ url: URL) throws { try Data(text.utf8).write(to: url) }
        func read(_ url: URL) -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "<missing>" }

        r.expectNoThrow("reset/backup scenario") {
            let mod = root.appendingPathComponent("mod")
            let backups = root.appendingPathComponent("backups")
            let pristine = root.appendingPathComponent("pristine")
            let vanillaSrc = root.appendingPathComponent("vanillaSrc")
            try makeDir(mod); try makeDir(vanillaSrc)

            // Live mod = tweaked; vanilla source = pristine values.
            try write("menus TWEAKED 100", mod.appendingPathComponent("menus.txt"))
            try write("ini TWEAKED", mod.appendingPathComponent("module.ini"))
            try write("ignore me", mod.appendingPathComponent("notes.md"))
            try write("menus VANILLA 20", vanillaSrc.appendingPathComponent("menus.txt"))
            try write("ini VANILLA", vanillaSrc.appendingPathComponent("module.ini"))

            let mgr = ModManager(modFolder: mod, backupsRoot: backups, pristineStore: pristine)
            r.expect(!mgr.hasPristineBaseline, "no baseline before import")

            let imported = try mgr.importPristineBaseline(from: vanillaSrc)
            r.expectEqual(imported, 2, "imported file count")
            r.expect(mgr.hasPristineBaseline, "baseline present after import")
            r.expect(mgr.canResetToDefaults, "canResetToDefaults after import")

            guard case .restored(let count, let safety) = try mgr.resetToDefaults() else {
                r.failures.append("resetToDefaults returned unavailable"); r.checks += 1; return
            }
            r.expectEqual(count, 2, "reset restored file count")
            // Live mod now holds vanilla content...
            r.expectEqual(read(mod.appendingPathComponent("menus.txt")), "menus VANILLA 20", "menus reset to vanilla")
            r.expectEqual(read(mod.appendingPathComponent("module.ini")), "ini VANILLA", "module.ini reset to vanilla")
            // ...non-module files untouched...
            r.expectEqual(read(mod.appendingPathComponent("notes.md")), "ignore me", "non-module file untouched")
            // ...and the safety backup captured the pre-reset tweaked content.
            r.expectEqual(read(safety.appendingPathComponent("menus.txt")), "menus TWEAKED 100", "safety backup has pre-reset content")
        }

        r.expectNoThrow("detect PoP Helper backup + ensure baseline") {
            let mod = root.appendingPathComponent("mod2")
            let phBackup = mod
                .appendingPathComponent("_backupHelper")
                .appendingPathComponent("Backup Your Files")
                .appendingPathComponent("[Tweaks] 26.10.23 15-03-18")
            try makeDir(mod); try makeDir(phBackup)
            try write("menus VANILLA", phBackup.appendingPathComponent("menus.txt"))
            try write("scripts VANILLA", phBackup.appendingPathComponent("scripts.txt"))
            try write("tweaked", mod.appendingPathComponent("menus.txt"))

            let mgr = ModManager(modFolder: mod,
                                 backupsRoot: root.appendingPathComponent("b2"),
                                 pristineStore: root.appendingPathComponent("p2"))
            r.expect(mgr.detectPoPHelperPristineBackup() != nil, "detects PoP Helper backup")
            r.expect(mgr.canResetToDefaults, "canReset via detected backup")
            let ensured = try mgr.ensurePristineBaseline()
            r.expect(ensured, "ensurePristineBaseline imports detected backup")
            r.expect(mgr.hasPristineBaseline, "baseline present after ensure")
        }
    }

    private static func packManager(_ r: Recorder) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("pophelper-packtest-\(getpid())")
        try? fm.removeItem(at: root)
        defer { try? fm.removeItem(at: root) }

        func write(_ text: String, _ url: URL) throws {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
        }
        func read(_ url: URL) -> String? { try? String(contentsOf: url, encoding: .utf8) }

        r.expectNoThrow("pack install/uninstall round trip") {
            let mod = root.appendingPathComponent("mod")
            let lib = root.appendingPathComponent("lib")
            let backups = root.appendingPathComponent("packbackups")
            let state = root.appendingPathComponent("state.json")

            // Live mod: an existing texture + a module.ini.
            try write("ORIGINAL-UI", mod.appendingPathComponent("Textures/user_interface_b.dds"))
            try write("header\nload_mod_resource = base\n", mod.appendingPathComponent("module.ini"))

            // Pack library: a "choice" pack (two options) + a brf "copy" pack needing a module resource.
            try write("UI-VARIANT-A", lib.appendingPathComponent("ui/files/a/user_interface_b.dds"))
            try write("UI-VARIANT-B", lib.appendingPathComponent("ui/files/b/user_interface_b.dds"))
            try write("BRFDATA", lib.appendingPathComponent("col/ColFix.brf"))

            let uiPack = Pack(
                id: "ui", name: LocalizedText(en: "UI", uk: "UI"),
                description: LocalizedText(en: "", uk: ""), kind: .choice, files: nil,
                options: [
                    PackOption(id: "a", name: LocalizedText(en: "A", uk: "A"), preview: nil,
                               files: [FileMapping(from: "files/a/user_interface_b.dds", to: "Textures/user_interface_b.dds")]),
                    PackOption(id: "b", name: LocalizedText(en: "B", uk: "B"), preview: nil,
                               files: [FileMapping(from: "files/b/user_interface_b.dds", to: "Textures/user_interface_b.dds")]),
                ], moduleResources: nil)
            let colPack = Pack(
                id: "col", name: LocalizedText(en: "Col", uk: "Col"),
                description: LocalizedText(en: "", uk: ""), kind: .copy,
                files: [FileMapping(from: "ColFix.brf", to: "Resource/ColFix.brf")],
                options: nil, moduleResources: ["ColFix"])

            let pm = PackManager(modFolder: mod, packsLibrary: lib, backupsRoot: backups, stateFile: state)
            r.expect(pm.isAvailable(uiPack) && pm.isAvailable(colPack), "packs available")
            r.expect(!pm.isInstalled("ui"), "ui not installed initially")

            // Install choice option A → existing file backed up & replaced.
            try pm.install(uiPack, optionId: "a")
            r.expectEqual(read(mod.appendingPathComponent("Textures/user_interface_b.dds")), "UI-VARIANT-A", "ui A applied")
            r.expectEqual(pm.installedOption("ui"), "a", "ui option recorded")

            // Switch to option B (reinstall).
            try pm.install(uiPack, optionId: "b")
            r.expectEqual(read(mod.appendingPathComponent("Textures/user_interface_b.dds")), "UI-VARIANT-B", "ui B applied")

            // Uninstall → original restored.
            try pm.uninstall(uiPack)
            r.expectEqual(read(mod.appendingPathComponent("Textures/user_interface_b.dds")), "ORIGINAL-UI", "ui restored to original")
            r.expect(!pm.isInstalled("ui"), "ui uninstalled")

            // brf copy pack: new file created + module.ini resource line added, then removed.
            try pm.install(colPack, optionId: nil)
            r.expectEqual(read(mod.appendingPathComponent("Resource/ColFix.brf")), "BRFDATA", "ColFix copied")
            r.expect(read(mod.appendingPathComponent("module.ini"))?.contains("load_mod_resource = ColFix") == true,
                     "module.ini resource line added")
            try pm.uninstall(colPack)
            r.expect(!fm.fileExists(atPath: mod.appendingPathComponent("Resource/ColFix.brf").path),
                     "ColFix removed (was absent before)")
            r.expect(read(mod.appendingPathComponent("module.ini"))?.contains("ColFix") != true,
                     "module.ini resource line removed")
        }
    }

    private static func gameConfig(_ r: Recorder) {
        // Parsing edge cases.
        r.expectEqual(GameConfigManager.parseLine("battle_size = 1.0000")?.key, "battle_size", "parse key")
        r.expectEqual(GameConfigManager.parseLine("battle_size = 1.0000")?.value, "1.0000", "parse value")
        r.expect(GameConfigManager.parseLine("") == nil, "blank line not parsed")
        r.expect(GameConfigManager.parseLine("# comment") == nil, "comment not parsed")
        r.expect(GameConfigManager.parseLine("key_only =") == nil, "empty value not parsed")

        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("pophelper-gctest-\(getpid())")
        try? fm.removeItem(at: root)
        defer { try? fm.removeItem(at: root) }

        r.expectNoThrow("rgl_config round trip") {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            let cfg = root.appendingPathComponent("rgl_config.txt")
            // All profile keys present (deliberately non-optimal) + an unknown key,
            // an unmanaged key, and a trailing blank line — write must edit in place.
            let original = """
            first_time = 1

            battle_size = 0.1200

            grass_density = 50

            unknown_key = hello

            enable_accurate_shadows = 1

            enable_environment_shadows = 1

            realistic_shadows_on_plants = 1

            """
            try Data(original.utf8).write(to: cfg)

            let mgr = GameConfigManager(configURL: cfg, backupsRoot: root.appendingPathComponent("bk"))
            r.expect(mgr.exists, "config exists")

            let read = try mgr.read()
            r.expect((read["battle_size"].map { abs($0 - 0.12) < 1e-9 }) == true, "read battle_size")
            r.expectEqual(read["grass_density"], 50, "read grass_density")
            r.expect(read["unknown_key"] == nil, "non-numeric value ignored")

            // Not yet optimal (battle_size broken, shadows on, grass 50).
            r.expect(!GamePerformance.isOptimal(read), "fixture not optimal")

            let backup = try mgr.backup()
            r.expect(fm.fileExists(atPath: backup.path), "backup created")

            // Apply the curated Mac profile.
            try mgr.write(GamePerformance.formattedProfile)
            let after = try String(contentsOf: cfg, encoding: .utf8)
            r.expect(after.contains("battle_size = 1.0000"), "battle_size set to max")
            r.expect(after.contains("grass_density = 25"), "grass lowered to 25")
            r.expect(after.contains("enable_accurate_shadows = 0"), "accurate shadows off")
            r.expect(after.contains("unknown_key = hello"), "unknown key preserved")
            r.expect(after.contains("first_time = 1"), "unmanaged key preserved")
            r.expectEqual(after.components(separatedBy: "\n").count,
                          original.components(separatedBy: "\n").count, "line/blank structure preserved")

            // Reading back now reports optimal.
            let reread = try mgr.read()
            r.expect(GamePerformance.isOptimal(reread), "optimal after applying profile")
        }
    }

    private static func bundledPackDatabase(_ r: Recorder) {
        r.expectNoThrow("load bundled packs.json") {
            let db = try PackDatabase.load()
            r.expectEqual(db.schemaVersion, 1, "packs schemaVersion")
            r.expect(!db.packs.isEmpty, "packs not empty")
            r.expectEqual(Set(db.packs.map(\.id)).count, db.packs.count, "unique pack ids")
            for pack in db.packs {
                r.expect(pack.name.en != "" && pack.name.uk != "", "\(pack.id): bilingual name")
                switch pack.kind {
                case .copy:
                    r.expect(!(pack.files ?? []).isEmpty, "\(pack.id): copy pack has files")
                case .choice:
                    r.expect(!(pack.options ?? []).isEmpty, "\(pack.id): choice pack has options")
                    for o in pack.options ?? [] {
                        r.expect(!o.files.isEmpty, "\(pack.id)/\(o.id): option has files")
                    }
                }
            }
        }
    }

    private static func bundledDatabase(_ r: Recorder) {
        r.expectNoThrow("load bundled DB") {
            let db = try TweakDatabase.load()
            r.expectEqual(db.schemaVersion, 1, "schemaVersion")
            r.expect(!db.tweaks.isEmpty, "DB not empty")
            r.expectEqual(Set(db.tweaks.map(\.id)).count, db.tweaks.count, "unique tweak ids")
            for tweak in db.tweaks {
                let declared = Set(tweak.params.map(\.key))
                var used: Set<String> = []
                for op in tweak.operations {
                    r.expect(TweakEngine.placeholderKeys(in: op.original, declaredKeys: declared).isEmpty,
                             "\(tweak.id): original must not contain param placeholders")
                    used.formUnion(TweakEngine.placeholderKeys(in: op.replacement, declaredKeys: declared))
                    if !op.isStructural,
                       !TweakEngine.placeholderKeys(in: op.replacement, declaredKeys: declared).isEmpty {
                        let originals = Dictionary(uniqueKeysWithValues: tweak.params.map { ($0.key, $0.originalValue) })
                        r.expectEqual(try TweakEngine.render(op.replacement, values: originals, declaredKeys: declared),
                                      op.original, "\(tweak.id): replacement(originals) must equal original")
                    }
                }
                r.expectEqual(used, declared, "\(tweak.id): all declared params must be used")
            }
        }
    }
}
