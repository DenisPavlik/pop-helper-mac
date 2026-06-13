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
        bundledDatabase(r)

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
        let op = TweakOperation(
            file: "f.txt", original: "needle 60", replacement: "needle {threshold}",
            occurrence: .all, expectedCount: 1)
        let t = tweak(params: [thresholdParam], operations: [op])
        if case .conflict = TweakEngine.status(of: t, files: ["f.txt": "something else"]) {} else {
            r.failures.append("expected conflict when pattern missing"); r.checks += 1
        }

        let opA = TweakOperation(file: "a.txt", original: "X 1", replacement: "X 2", occurrence: .all, expectedCount: 1)
        let opB = TweakOperation(file: "b.txt", original: "Y 1", replacement: "Y 2", occurrence: .all, expectedCount: 1)
        let t2 = tweak(operations: [opA, opB])
        if case .conflict = TweakEngine.status(of: t2, files: ["a.txt": "X 2", "b.txt": "Y 1"]) {} else {
            r.failures.append("expected conflict when partially applied"); r.checks += 1
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
