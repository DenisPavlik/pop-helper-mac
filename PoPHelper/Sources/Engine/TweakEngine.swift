import Foundation

enum TweakEngineError: LocalizedError {
    case missingValue(key: String)
    case fileMissing(String)
    case notInExpectedState(tweakID: String, detail: String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            return "No value provided for parameter {\(key)}"
        case .fileMissing(let name):
            return "Mod file not found: \(name)"
        case .notInExpectedState(let id, let detail):
            return "Tweak \(id) is not in the expected state: \(detail)"
        }
    }
}

/// Pure string-patching engine. File IO lives in ModManager.
///
/// A `{token}` in a template is a *parameter placeholder* only when `token` is
/// one of the tweak's declared param keys (`declaredKeys`). Every other brace
/// token is literal text — Warband module files are full of register tokens
/// like `{s3}`, `{reg9}`, `{reg24}` that must survive verbatim.
enum TweakEngine {

    // MARK: Templates

    private enum Segment {
        case literal(String)
        case placeholder(String)
    }

    private static func segments(of template: String, declaredKeys: Set<String>) -> [Segment] {
        var result: [Segment] = []
        var literal = ""
        var rest = Substring(template)
        while let open = rest.firstIndex(of: "{") {
            guard let close = rest[open...].firstIndex(of: "}") else { break }
            let key = String(rest[rest.index(after: open)..<close])
            if declaredKeys.contains(key) {
                literal += rest[..<open]
                result.append(.literal(literal))
                literal = ""
                result.append(.placeholder(key))
                rest = rest[rest.index(after: close)...]
            } else {
                // Not a declared param → keep the whole `{…}` span as literal text.
                literal += rest[..<rest.index(after: close)]
                rest = rest[rest.index(after: close)...]
            }
        }
        literal += rest
        if !literal.isEmpty { result.append(.literal(literal)) }
        return result
    }

    static func placeholderKeys(in template: String, declaredKeys: Set<String>) -> [String] {
        segments(of: template, declaredKeys: declaredKeys).compactMap {
            if case .placeholder(let key) = $0 { return key } else { return nil }
        }
    }

    static func render(_ template: String, values: [String: Int], declaredKeys: Set<String>) throws -> String {
        var out = ""
        for segment in segments(of: template, declaredKeys: declaredKeys) {
            switch segment {
            case .literal(let s): out += s
            case .placeholder(let key):
                guard let v = values[key] else { throw TweakEngineError.missingValue(key: key) }
                out += String(v)
            }
        }
        return out
    }

    /// Regex matching the rendered template with any integer values; group i captures the i-th placeholder.
    /// Compiled regexes are cached: status() rebuilds these for every applied op on every
    /// reload, and `NSRegularExpression(pattern:)` compilation is expensive.
    private static var regexCache: [String: (NSRegularExpression, [String])] = [:]
    static func regex(for template: String, declaredKeys: Set<String>) throws -> (regex: NSRegularExpression, keys: [String]) {
        let cacheKey = template + "\u{1}" + declaredKeys.sorted().joined(separator: "\u{2}")
        if let hit = regexCache[cacheKey] { return hit }
        var pattern = ""
        var keys: [String] = []
        for segment in segments(of: template, declaredKeys: declaredKeys) {
            switch segment {
            case .literal(let s): pattern += NSRegularExpression.escapedPattern(for: s)
            case .placeholder(let key):
                pattern += "(-?\\d+)"
                keys.append(key)
            }
        }
        let compiled = (try NSRegularExpression(pattern: pattern), keys)
        regexCache[cacheKey] = compiled
        return compiled
    }

    private static func declaredKeys(of tweak: Tweak) -> Set<String> {
        Set(tweak.params.map(\.key))
    }

    // MARK: Matching helpers

    private static func ranges(of needle: String, in haystack: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var searchFrom = haystack.startIndex
        while let r = haystack.range(of: needle, range: searchFrom..<haystack.endIndex) {
            result.append(r)
            searchFrom = r.upperBound
        }
        return result
    }

    /// Fast count of non-overlapping literal occurrences. NSString's search is C-backed
    /// and dramatically faster than Swift `String.range(of:)` on the large module files —
    /// status() runs a count for every op of every tweak on each reload, so this is the
    /// difference between a responsive UI and a ~20s freeze.
    static func count(of needle: String, in haystack: NSString) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var start = 0
        while start < haystack.length {
            let found = haystack.range(of: needle, options: .literal,
                                       range: NSRange(location: start, length: haystack.length - start))
            if found.location == NSNotFound { break }
            count += 1
            start = found.location + found.length
        }
        return count
    }

    /// Convenience for the rare String-based callers (apply/revert).
    static func count(of needle: String, in haystack: String) -> Int {
        count(of: needle, in: haystack as NSString)
    }

    // MARK: Byte-level matching (status hot path)
    // The status check runs over every op of every tweak on each reload; with ~250 ops
    // against multi-MB files, String/NSString scanning and NSRegularExpression are far too
    // slow (~13s). These operate on UTF-8 byte arrays (built once per file) using memmem.

    /// memmem-based count of non-overlapping literal occurrences.
    static func count(of needle: [UInt8], in hay: [UInt8]) -> Int {
        guard !needle.isEmpty, hay.count >= needle.count else { return 0 }
        var total = 0
        hay.withUnsafeBytes { hraw in
            needle.withUnsafeBytes { nraw in
                let hbase = hraw.baseAddress!, nbase = nraw.baseAddress!
                let hlen = hraw.count, nlen = nraw.count
                var offset = 0
                while hlen - offset >= nlen {
                    guard let found = memmem(hbase + offset, hlen - offset, nbase, nlen) else { break }
                    total += 1
                    offset = (UnsafeRawPointer(found) - hbase) + nlen
                }
            }
        }
        return total
    }

    private enum BSeg { case lit([UInt8]); case num(String) }

    /// Byte-level pattern scan for status. In ONE pass over `hay`, anchored on the
    /// replacement template's first literal segment (which is distinctive — it carries the
    /// long PoP reference numbers — so memmem skips through the file fast even when absent),
    /// it counts pattern matches that are byte-equal to `op.original` (orig) vs different
    /// (applied), and captures the first applied match's param values. Doing both counts in
    /// one anchored scan avoids a separate, costly full-file search for the long `op.original`
    /// string (which, once a tweak is applied, is absent and would scan the whole file).
    /// Mirrors the regex `(-?\d+)` (greedy) + literal semantics. nil when the template has no
    /// leading literal anchor (caller falls back to the regex path).
    static func scanPattern(of op: TweakOperation, declaredKeys: Set<String>,
                            hay: [UInt8]) -> (orig: Int, applied: Int, firstValues: [String: Int])? {
        let segs: [BSeg] = segments(of: op.replacement, declaredKeys: declaredKeys).map {
            switch $0 {
            case .literal(let s): return .lit(Array(s.utf8))
            case .placeholder(let k): return .num(k)
            }
        }
        // Anchor on the first non-empty literal. The template may start with one placeholder
        // (e.g. "{hours}.000000 …"); in that case the match starts just before the anchor and
        // we back-parse the leading number. Two or more leading placeholders are ambiguous to
        // anchor → nil (caller falls back to regex; very rare).
        guard let anchorIdx = segs.firstIndex(where: {
            if case .lit(let b) = $0 { return !b.isEmpty } else { return false }
        }), case .lit(let anchor) = segs[anchorIdx] else { return nil }
        // How many placeholders precede the anchor (segments() emits an empty leading literal
        // before a starting placeholder). 0 → match starts at the anchor; 1 → back-parse one
        // leading number; ≥2 → ambiguous, fall back.
        let leadingPlaceholders = segs[0..<anchorIdx].reduce(0) { n, s in
            if case .num = s { return n + 1 } else { return n }
        }
        guard leadingPlaceholders <= 1 else { return nil }
        let originalBytes = Array(op.original.utf8)
        var orig = 0, applied = 0
        var firstValues: [String: Int] = [:]
        hay.withUnsafeBufferPointer { hb in
            anchor.withUnsafeBytes { araw in
                let hbase = UnsafeRawPointer(hb.baseAddress!)
                let hcount = hb.count
                var from = 0
                while hcount - from >= anchor.count {
                    guard let found = memmem(hbase + from, hcount - from, araw.baseAddress!, anchor.count) else { break }
                    let p = UnsafeRawPointer(found) - hbase
                    // Match start: the anchor itself (no leading placeholder), or back over the
                    // single leading placeholder's number (digits, then an optional '-').
                    var matchStart = p
                    if leadingPlaceholders == 1 {
                        while matchStart > 0, hb[matchStart - 1] >= 0x30, hb[matchStart - 1] <= 0x39 { matchStart -= 1 }
                        if matchStart > 0, hb[matchStart - 1] == 0x2D { matchStart -= 1 }
                    }
                    if let (endPos, values) = matchTemplate(segs, in: hb, at: matchStart) {
                        var isOrig = (endPos - matchStart) == originalBytes.count
                        if isOrig {
                            for i in 0..<originalBytes.count where hb[matchStart + i] != originalBytes[i] { isOrig = false; break }
                        }
                        if isOrig {
                            orig += 1
                        } else {
                            applied += 1
                            if applied == 1 { firstValues = values }
                        }
                        from = max(endPos, p + 1)
                    } else {
                        from = p + 1
                    }
                }
            }
        }
        return (orig, applied, firstValues)
    }

    private static func matchTemplate(_ segs: [BSeg], in hay: UnsafeBufferPointer<UInt8>,
                                      at start: Int) -> (end: Int, values: [String: Int])? {
        var pos = start
        var values: [String: Int] = [:]
        for seg in segs {
            switch seg {
            case .lit(let bytes):
                if pos + bytes.count > hay.count { return nil }
                for i in 0..<bytes.count where hay[pos + i] != bytes[i] { return nil }
                pos += bytes.count
            case .num(let key):
                var j = pos
                var neg = false
                if j < hay.count, hay[j] == 0x2D { neg = true; j += 1 }   // '-'
                let digitStart = j
                while j < hay.count, hay[j] >= 0x30, hay[j] <= 0x39 { j += 1 }   // 0-9
                if j == digitStart { return nil }
                var v = 0
                for k in digitStart..<j { v = v * 10 + Int(hay[k] - 0x30) }
                values[key] = neg ? -v : v
                pos = j
            }
        }
        return (pos, values)
    }

    private static func selectedCount(of op: TweakOperation) -> Int {
        switch op.occurrence {
        case .all: return op.expectedCount
        case .indices(let list): return list.count
        }
    }

    /// Regex matches of the replacement template that are NOT byte-equal to `original`
    /// (the template also matches the pristine text, since only numbers differ).
    private static func appliedMatches(
        of op: TweakOperation, declaredKeys: Set<String>, in content: String
    ) throws -> [(range: Range<String.Index>, values: [String: Int])] {
        let (re, keys) = try regex(for: op.replacement, declaredKeys: declaredKeys)
        let ns = content as NSString
        let full = NSRange(location: 0, length: ns.length)
        var result: [(Range<String.Index>, [String: Int])] = []
        re.enumerateMatches(in: content, range: full) { match, _, _ in
            guard let match, let range = Range(match.range, in: content) else { return }
            if String(content[range]) == op.original { return }
            var values: [String: Int] = [:]
            for (i, key) in keys.enumerated() {
                if let r = Range(match.range(at: i + 1), in: content) {
                    values[key] = Int(content[r])
                }
            }
            result.append((range, values))
        }
        return result
    }

    // MARK: Status

    static func status(of tweak: Tweak, files: [String: String]) -> TweakStatus {
        // Convert each file to a UTF-8 byte array once. Callers that score many tweaks in a
        // row (reload/--status) should build byteFiles once and call the byteFiles overload
        // so each file is converted a single time for the whole batch.
        status(of: tweak, byteFiles: files.mapValues { Array($0.utf8) })
    }

    static func status(of tweak: Tweak, byteFiles: [String: [UInt8]]) -> TweakStatus {
        let keys = declaredKeys(of: tweak)
        var anyApplied = false
        var anyExternal = false   // an op whose vanilla form is entirely gone & not our applied form
        var values: [String: Int] = [:]
        var externalDetail = ""
        for op in tweak.operations {
            guard let hay = byteFiles[op.file] else {
                return .conflict(detail: "missing file \(op.file)")
            }
            let selected = selectedCount(of: op)
            // The exact count of op.original is the pristine gate — robust for structural
            // tweaks whose replacement changes literal (non-placeholder) bytes, where the
            // replacement pattern would not even match the original text.
            let originalCount = count(of: Array(op.original.utf8), in: hay)
            if originalCount == op.expectedCount { continue }   // at pristine for this op
            let placeholders = placeholderKeys(in: op.replacement, declaredKeys: keys)
            let appliedCount: Int
            var firstValues: [String: Int] = [:]
            if placeholders.isEmpty {
                // Parameterless op: applied form is a fixed literal.
                appliedCount = count(of: Array(op.replacement.utf8), in: hay)
            } else if let scan = scanPattern(of: op, declaredKeys: keys, hay: hay) {
                // Parameterised op: one anchored byte scan counts applied matches + values.
                appliedCount = scan.applied
                firstValues = scan.firstValues
            } else {
                // Template has 2+ leading placeholders (no usable anchor) — regex fallback. Rare.
                let content = String(decoding: hay, as: UTF8.self)
                guard let applied = try? appliedMatches(of: op, declaredKeys: keys, in: content) else {
                    return .conflict(detail: "\(op.file): found \(originalCount)/\(op.expectedCount) pristine occurrences")
                }
                appliedCount = applied.count
                if let first = applied.first { firstValues = first.values }
            }
            if originalCount == op.expectedCount - selected, appliedCount == selected {
                anyApplied = true
                values.merge(firstValues) { current, _ in current }
                continue
            }
            // The vanilla pattern is entirely absent. Our patterns are validated against the
            // pristine baseline and we never apply a tweak unless the vanilla form is present,
            // so its complete absence means this location was changed by something other than
            // PoP Helper Mac — in practice the original Windows PoP Helper applied this tweak in
            // its own byte variant (which may not match our applied form, or may match it an
            // unexpected number of times). Treat as already-applied-elsewhere, not a conflict.
            if originalCount == 0 {
                anyExternal = true
                if externalDetail.isEmpty { externalDetail = "\(op.file): vanilla form absent (already modified outside PoP Helper Mac)" }
                continue
            }
            // Some — but not all — vanilla occurrences remain and it isn't cleanly applied:
            // a genuinely partial/ambiguous state → real conflict.
            return .conflict(detail: "\(op.file): found \(originalCount)/\(op.expectedCount) pristine occurrences")
        }
        // A touched-but-unrecognised op means we can't cleanly toggle the tweak; report it as
        // already applied (locked) even if other ops happen to sit at their vanilla value.
        if anyExternal { return .appliedExternally(detail: externalDetail) }
        guard anyApplied else { return .notApplied }
        // Knobs left at their vanilla value read back as the original value.
        for param in tweak.params where values[param.key] == nil {
            values[param.key] = param.originalValue
        }
        return .applied(values: values)
    }

    // MARK: Apply / revert

    /// Returns the set of file names actually modified.
    @discardableResult
    static func apply(
        _ tweak: Tweak, values: [String: Int], to files: inout [String: String]
    ) throws -> Set<String> {
        let keys = declaredKeys(of: tweak)
        var touched: Set<String> = []
        for op in tweak.operations {
            guard var content = files[op.file] else { throw TweakEngineError.fileMissing(op.file) }
            for key in placeholderKeys(in: op.replacement, declaredKeys: keys) where values[key] == nil {
                throw TweakEngineError.missingValue(key: key)
            }
            let occurrences = ranges(of: op.original, in: content)
            guard occurrences.count == op.expectedCount else {
                throw TweakEngineError.notInExpectedState(
                    tweakID: tweak.id,
                    detail: "\(op.file): expected \(op.expectedCount) pristine occurrences, found \(occurrences.count)")
            }
            let selected: [Range<String.Index>]
            switch op.occurrence {
            case .all:
                selected = occurrences
            case .indices(let list):
                selected = list.compactMap { $0 >= 1 && $0 <= occurrences.count ? occurrences[$0 - 1] : nil }
            }
            let rendered = try render(op.replacement, values: values, declaredKeys: keys)
            for range in selected.reversed() {
                content.replaceSubrange(range, with: rendered)
            }
            files[op.file] = content
            touched.insert(op.file)
        }
        return touched
    }

    @discardableResult
    static func revert(_ tweak: Tweak, in files: inout [String: String]) throws -> Set<String> {
        let keys = declaredKeys(of: tweak)
        var touched: Set<String> = []
        for op in tweak.operations {
            guard var content = files[op.file] else { throw TweakEngineError.fileMissing(op.file) }
            let matches = try appliedMatches(of: op, declaredKeys: keys, in: content)
            // No applied form present → nothing to revert for this op. Covers a knob left at its
            // vanilla value (its applied form == original, filtered out of `matches`).
            // IMPORTANT: this must be checked BEFORE any `count(original) == expectedCount` gate.
            // A structural *append* op's `original` is a prefix of its `replacement`, so the
            // original string is still present after apply — a count gate alone would wrongly
            // conclude "already vanilla" and skip the revert, leaving the appended lines behind.
            if matches.isEmpty {
                if count(of: op.original, in: content) == op.expectedCount { continue }
                throw TweakEngineError.notInExpectedState(
                    tweakID: tweak.id,
                    detail: "\(op.file): nothing to revert and not at pristine")
            }
            guard matches.count == selectedCount(of: op) else {
                throw TweakEngineError.notInExpectedState(
                    tweakID: tweak.id,
                    detail: "\(op.file): expected \(selectedCount(of: op)) applied occurrences, found \(matches.count)")
            }
            for match in matches.reversed() {
                content.replaceSubrange(match.range, with: op.original)
            }
            files[op.file] = content
            touched.insert(op.file)
        }
        return touched
    }
}
