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
    static func regex(for template: String, declaredKeys: Set<String>) throws -> (regex: NSRegularExpression, keys: [String]) {
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
        return (try NSRegularExpression(pattern: pattern), keys)
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
        let keys = declaredKeys(of: tweak)
        var anyApplied = false
        var values: [String: Int] = [:]
        for op in tweak.operations {
            guard let content = files[op.file] else {
                return .conflict(detail: "missing file \(op.file)")
            }
            let originalCount = ranges(of: op.original, in: content).count
            let selected = selectedCount(of: op)
            // Op text equals pristine — either the tweak isn't applied, or this
            // particular knob is left at its vanilla value. Not a conflict.
            if originalCount == op.expectedCount {
                continue
            }
            guard let applied = try? appliedMatches(of: op, declaredKeys: keys, in: content),
                  originalCount == op.expectedCount - selected,
                  applied.count == selected
            else {
                return .conflict(detail: "\(op.file): found \(originalCount)/\(op.expectedCount) pristine occurrences")
            }
            anyApplied = true
            if let first = applied.first {
                values.merge(first.values) { current, _ in current }
            }
        }
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
            // Knob already at its vanilla value → nothing to revert for this op.
            if ranges(of: op.original, in: content).count == op.expectedCount {
                continue
            }
            let matches = try appliedMatches(of: op, declaredKeys: keys, in: content)
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
