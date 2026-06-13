import Foundation

enum TweakEngineError: LocalizedError {
    case unknownPlaceholder(String)
    case missingValue(key: String)
    case fileMissing(String)
    case notInExpectedState(tweakID: String, detail: String)

    var errorDescription: String? {
        switch self {
        case .unknownPlaceholder(let key):
            return "Template references undeclared parameter {\(key)}"
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
enum TweakEngine {

    // MARK: Templates

    /// Splits a template into literal chunks and `{key}` placeholders.
    private enum Segment {
        case literal(String)
        case placeholder(String)
    }

    private static func segments(of template: String) -> [Segment] {
        var result: [Segment] = []
        var literal = ""
        var rest = Substring(template)
        while let open = rest.firstIndex(of: "{") {
            guard let close = rest[open...].firstIndex(of: "}") else { break }
            let key = String(rest[rest.index(after: open)..<close])
            // Only treat simple identifiers as placeholders; anything else is literal text.
            if !key.isEmpty, key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                literal += rest[..<open]
                result.append(.literal(literal))
                literal = ""
                result.append(.placeholder(key))
                rest = rest[rest.index(after: close)...]
            } else {
                literal += rest[..<rest.index(after: close)]
                rest = rest[rest.index(after: close)...]
            }
        }
        literal += rest
        if !literal.isEmpty { result.append(.literal(literal)) }
        return result
    }

    static func placeholderKeys(in template: String) -> [String] {
        segments(of: template).compactMap {
            if case .placeholder(let key) = $0 { return key } else { return nil }
        }
    }

    static func render(_ template: String, values: [String: Int]) throws -> String {
        var out = ""
        for segment in segments(of: template) {
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
    static func regex(for template: String) throws -> (regex: NSRegularExpression, keys: [String]) {
        var pattern = ""
        var keys: [String] = []
        for segment in segments(of: template) {
            switch segment {
            case .literal(let s): pattern += NSRegularExpression.escapedPattern(for: s)
            case .placeholder(let key):
                pattern += "(-?\\d+)"
                keys.append(key)
            }
        }
        return (try NSRegularExpression(pattern: pattern), keys)
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
        of op: TweakOperation, in content: String
    ) throws -> [(range: Range<String.Index>, values: [String: Int])] {
        let (re, keys) = try regex(for: op.replacement)
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
        var anyApplied = false
        var anyNotApplied = false
        var values: [String: Int] = [:]
        for op in tweak.operations {
            guard let content = files[op.file] else {
                return .conflict(detail: "missing file \(op.file)")
            }
            let originalCount = ranges(of: op.original, in: content).count
            let selected = selectedCount(of: op)
            if originalCount == op.expectedCount {
                anyNotApplied = true
                continue
            }
            guard let applied = try? appliedMatches(of: op, in: content),
                  originalCount == op.expectedCount - selected,
                  applied.count >= selected
            else {
                return .conflict(detail: "\(op.file): found \(originalCount)/\(op.expectedCount) pristine occurrences")
            }
            anyApplied = true
            if let first = applied.first {
                values.merge(first.values) { current, _ in current }
            }
        }
        if anyApplied && anyNotApplied {
            return .conflict(detail: "partially applied")
        }
        return anyApplied ? .applied(values: values) : .notApplied
    }

    // MARK: Apply / revert

    /// Returns the set of file names actually modified.
    @discardableResult
    static func apply(
        _ tweak: Tweak, values: [String: Int], to files: inout [String: String]
    ) throws -> Set<String> {
        var touched: Set<String> = []
        for op in tweak.operations {
            guard var content = files[op.file] else { throw TweakEngineError.fileMissing(op.file) }
            for key in placeholderKeys(in: op.replacement) where values[key] == nil {
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
            let rendered = try render(op.replacement, values: values)
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
        var touched: Set<String> = []
        for op in tweak.operations {
            guard var content = files[op.file] else { throw TweakEngineError.fileMissing(op.file) }
            let matches = try appliedMatches(of: op, in: content)
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
