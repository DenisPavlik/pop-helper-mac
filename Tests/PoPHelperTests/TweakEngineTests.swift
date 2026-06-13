import XCTest
@testable import PoPHelper

final class TweakEngineTests: XCTestCase {

    private func makeTweak(
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

    private let thresholdParam = TweakParam(
        key: "threshold",
        name: LocalizedText(en: "Threshold", uk: "Поріг"),
        originalValue: 60, defaultValue: -100, min: -100, max: 150, presets: nil)

    // MARK: Templates

    func testRenderAndPlaceholders() throws {
        let template = "a b {threshold} c {threshold}"
        XCTAssertEqual(TweakEngine.placeholderKeys(in: template), ["threshold", "threshold"])
        XCTAssertEqual(try TweakEngine.render(template, values: ["threshold": -100]), "a b -100 c -100")
    }

    func testNonIdentifierBracesAreLiteral() throws {
        let template = "say {s9} and {threshold}"
        XCTAssertEqual(TweakEngine.placeholderKeys(in: template), ["threshold"])
        XCTAssertEqual(try TweakEngine.render(template, values: ["threshold": 5]), "say {s9} and 5")
    }

    func testRenderMissingValueThrows() {
        XCTAssertThrowsError(try TweakEngine.render("{x}", values: [:]))
    }

    // MARK: Status / apply / revert round trip

    func testApplyRevertRoundTrip() throws {
        let op = TweakOperation(
            file: "menus.txt",
            original: "2147483678 2 1224979098644774956 60",
            replacement: "2147483678 2 1224979098644774956 {threshold}",
            occurrence: .all,
            expectedCount: 1)
        let tweak = makeTweak(params: [thresholdParam], operations: [op])
        let pristine = "head 2147483678 2 1224979098644774956 60 tail"
        var files = ["menus.txt": pristine]

        XCTAssertEqual(TweakEngine.status(of: tweak, files: files), .notApplied)

        try TweakEngine.apply(tweak, values: ["threshold": -100], to: &files)
        XCTAssertEqual(files["menus.txt"], "head 2147483678 2 1224979098644774956 -100 tail")
        XCTAssertEqual(TweakEngine.status(of: tweak, files: files), .applied(values: ["threshold": -100]))

        try TweakEngine.revert(tweak, in: &files)
        XCTAssertEqual(files["menus.txt"], pristine)
        XCTAssertEqual(TweakEngine.status(of: tweak, files: files), .notApplied)
    }

    func testMultiOccurrenceAll() throws {
        let op = TweakOperation(
            file: "scripts.txt",
            original: "4 0 30 2 X 60",
            replacement: "4 0 30 2 X {threshold}",
            occurrence: .all,
            expectedCount: 2)
        let tweak = makeTweak(params: [thresholdParam], operations: [op])
        var files = ["scripts.txt": "4 0 30 2 X 60 mid 4 0 30 2 X 60 end"]

        try TweakEngine.apply(tweak, values: ["threshold": 0], to: &files)
        XCTAssertEqual(files["scripts.txt"], "4 0 30 2 X 0 mid 4 0 30 2 X 0 end")
        XCTAssertEqual(TweakEngine.status(of: tweak, files: files), .applied(values: ["threshold": 0]))

        try TweakEngine.revert(tweak, in: &files)
        XCTAssertEqual(TweakEngine.status(of: tweak, files: files), .notApplied)
    }

    func testSelectiveOccurrence() throws {
        let op = TweakOperation(
            file: "f.txt",
            original: "AA 7 BB",
            replacement: "AA {v} BB",
            occurrence: .indices([2]),
            expectedCount: 2)
        let param = TweakParam(
            key: "v", name: LocalizedText(en: "v", uk: "v"),
            originalValue: 7, defaultValue: 99, min: nil, max: nil, presets: nil)
        let tweak = makeTweak(params: [param], operations: [op])
        var files = ["f.txt": "AA 7 BB | AA 7 BB"]

        try TweakEngine.apply(tweak, values: ["v": 99], to: &files)
        XCTAssertEqual(files["f.txt"], "AA 7 BB | AA 99 BB")
        XCTAssertEqual(TweakEngine.status(of: tweak, files: files), .applied(values: ["v": 99]))

        try TweakEngine.revert(tweak, in: &files)
        XCTAssertEqual(files["f.txt"], "AA 7 BB | AA 7 BB")
    }

    func testNoParamFullReplacement() throws {
        let op = TweakOperation(
            file: "f.txt",
            original: "old block 1 2 3",
            replacement: "new block 4 5 6",
            occurrence: .all,
            expectedCount: 1)
        let tweak = makeTweak(operations: [op])
        var files = ["f.txt": "pre old block 1 2 3 post"]

        try TweakEngine.apply(tweak, values: [:], to: &files)
        XCTAssertEqual(files["f.txt"], "pre new block 4 5 6 post")
        XCTAssertEqual(TweakEngine.status(of: tweak, files: files), .applied(values: [:]))

        try TweakEngine.revert(tweak, in: &files)
        XCTAssertEqual(files["f.txt"], "pre old block 1 2 3 post")
    }

    // MARK: Conflict detection

    func testConflictWhenPatternMissing() {
        let op = TweakOperation(
            file: "f.txt",
            original: "needle 60",
            replacement: "needle {threshold}",
            occurrence: .all,
            expectedCount: 1)
        let tweak = makeTweak(params: [thresholdParam], operations: [op])
        let files = ["f.txt": "something else entirely"]
        guard case .conflict = TweakEngine.status(of: tweak, files: files) else {
            return XCTFail("expected conflict")
        }
    }

    func testConflictWhenPartiallyApplied() {
        let opA = TweakOperation(
            file: "a.txt", original: "X 1", replacement: "X 2", occurrence: .all, expectedCount: 1)
        let opB = TweakOperation(
            file: "b.txt", original: "Y 1", replacement: "Y 2", occurrence: .all, expectedCount: 1)
        let tweak = makeTweak(operations: [opA, opB])
        let files = ["a.txt": "X 2", "b.txt": "Y 1"]
        guard case .conflict = TweakEngine.status(of: tweak, files: files) else {
            return XCTFail("expected conflict")
        }
    }

    func testApplyRefusesUnexpectedState() {
        let op = TweakOperation(
            file: "f.txt", original: "X 1", replacement: "X 2", occurrence: .all, expectedCount: 2)
        let tweak = makeTweak(operations: [op])
        var files = ["f.txt": "X 1"]
        XCTAssertThrowsError(try TweakEngine.apply(tweak, values: [:], to: &files))
        XCTAssertEqual(files["f.txt"], "X 1")
    }

    // MARK: Database decoding

    func testOccurrenceDecoding() throws {
        let json = """
        [{"file":"f","original":"a","replacement":"b","occurrence":"all","expectedCount":1},
         {"file":"f","original":"a","replacement":"b","occurrence":[1,3],"expectedCount":3}]
        """
        let ops = try JSONDecoder().decode([TweakOperation].self, from: Data(json.utf8))
        XCTAssertEqual(ops[0].occurrence, .all)
        XCTAssertEqual(ops[1].occurrence, .indices([1, 3]))
    }

    func testBundledDatabaseDecodesAndIsConsistent() throws {
        let db = try TweakDatabase.load()
        XCTAssertEqual(db.schemaVersion, 1)
        XCTAssertFalse(db.tweaks.isEmpty)
        XCTAssertEqual(Set(db.tweaks.map(\.id)).count, db.tweaks.count, "duplicate tweak ids")
        for tweak in db.tweaks {
            let declared = Set(tweak.params.map(\.key))
            for op in tweak.operations {
                XCTAssertTrue(TweakEngine.placeholderKeys(in: op.original).isEmpty,
                              "\(tweak.id): `original` must be literal")
                for key in TweakEngine.placeholderKeys(in: op.replacement) {
                    XCTAssertTrue(declared.contains(key), "\(tweak.id): undeclared param {\(key)}")
                }
                // For value-only operations, rendering the replacement with the
                // original values must reproduce `original` byte-exactly.
                let originals = Dictionary(uniqueKeysWithValues: tweak.params.map { ($0.key, $0.originalValue) })
                if !op.isStructural, !TweakEngine.placeholderKeys(in: op.replacement).isEmpty {
                    XCTAssertEqual(try TweakEngine.render(op.replacement, values: originals), op.original,
                                   "\(tweak.id): replacement(originalValues) != original")
                }
            }
        }
    }
}
