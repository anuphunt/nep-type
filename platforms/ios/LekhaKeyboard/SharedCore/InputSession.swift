import Foundation

/// State for one input client. It never reads or stores the host application's text.
public struct InputSession: Sendable {
    public private(set) var roman = ""
    public private(set) var context: [String] = []
    public private(set) var selection = 0
    public private(set) var language: TypingLanguage = .nepali
    // Remember an open backtick span across whitespace without reading host text.
    private var codeBeforeToken = false
    // Track whether the current sentence actually committed Nepali text,
    // without retaining previously typed host text.
    private var sentenceHasNepali = false
    private let engine = Transliterator()
    public init() {}
    public var isComposing: Bool { !roman.isEmpty }
    /// Keep a whole whitespace-delimited token marked until its boundary. A
    /// later slash, dot or at-sign can then restore its original spelling.
    /// This is deliberately conservative for identifiers and code.
    private var tokenParts: (String, String, String)? {
        guard !codeBeforeToken else { return nil }
        let pattern = #"^([("'\[]*)([A-Za-z]+)([.,!?;:)'\]]*)$"#
        let re = try! NSRegularExpression(pattern: pattern)
        let source = roman as NSString
        guard let match = re.firstMatch(in: roman, range: NSRange(location: 0, length: source.length)) else { return nil }
        let word = source.substring(with: match.range(at: 2))
        // A colon may be the beginning of a URL scheme; do not convert it.
        guard !roman.contains(":"),
              !(word.first?.isLowercase == true && word.dropFirst().contains(where: { $0.isUppercase })) else { return nil }
        return (source.substring(with: match.range(at: 1)), word, source.substring(with: match.range(at: 3)))
    }
    private var codeAfterToken: Bool {
        roman.reduce(codeBeforeToken) { state, character in character == "`" ? !state : state }
    }
    // A final period may be followed by closing brackets or quotes. Preserve
    // ellipses, common abbreviations and nonterminal dots in literal tokens.
    private func terminalPeriod(in suffix: String, word: String) -> String.Index? {
        let abbreviations: Set<String> = ["mr", "mrs", "ms", "dr", "prof", "sr", "jr", "st", "vs", "etc"]
        guard !abbreviations.contains(word.lowercased()) else { return nil }
        for index in suffix.indices where suffix[index] == "." {
            let previousIsDot = index != suffix.startIndex && suffix[suffix.index(before: index)] == "."
            let following = suffix[suffix.index(after: index)...]
            if !previousIsDot && following.allSatisfy({ ")]}'".contains($0) }) { return index }
        }
        return nil
    }

    public var candidates: [String] {
        guard isComposing else { return [] }
        guard let (prefix, word, suffix) = tokenParts else { return [roman] }
        // Prefix punctuation breaks adjacency with preceding context.
        let preceding = prefix.isEmpty ? context : []
        let text = (preceding + [word]).joined(separator: " ")
        guard let choice = engine.contextChoices(in: text, language: language).last else { return [roman] }
        let alternatives = engine.contextualCandidates(for: choice)
        var results: [String] = []
        var seen = Set<String>()
        for (index, alternative) in alternatives.enumerated() {
            var ending = suffix
            let containsNepali = alternative.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) }
            // Preserve the separately offered original exactly. A leading
            // English candidate may still end a mixed Nepali sentence.
            let originalAlternative = alternative == word && index != 0
            if !originalAlternative && (sentenceHasNepali || containsNepali),
               let stop = terminalPeriod(in: ending, word: word) {
                ending.replaceSubrange(stop...stop, with: "।")
            }
            let candidate = prefix + alternative + ending
            if seen.insert(candidate).inserted { results.append(candidate) }
        }
        if seen.insert(roman).inserted { results.append(roman) }
        return results
    }
    public var markedText: String {
        let options = candidates
        return options.isEmpty ? "" : options[min(selection, options.count - 1)]
    }
    public mutating func append(_ text: String) -> Bool {
        guard language != .english, !text.isEmpty,
              text.unicodeScalars.allSatisfy({ (33...126).contains(Int($0.value)) }) else { return false }
        roman += text; selection = 0; return true
    }
    public mutating func backspace() -> Bool {
        guard isComposing else { return false }
        roman.removeLast(); selection = 0; return true
    }
    public mutating func cycle(_ delta: Int) {
        let count = candidates.count
        guard count > 0 else { return }
        selection = (selection + delta % count + count) % count
    }
    public mutating func select(_ value: String) -> Bool {
        guard let index = candidates.firstIndex(of: value) else { return false }
        selection = index; return true
    }
    public mutating func commit(keepContext: Bool = false, keepLiteralState: Bool = false) -> String? {
        guard isComposing else { return nil }
        let result = markedText
        let nextCodeState = codeAfterToken
        let parts = tokenParts
        if let (prefix, word, suffix) = parts, keepContext {
            // The ranker uses only directly adjacent words, so punctuation
            // before or after a token must not be silently removed.
            if !prefix.isEmpty { context.removeAll() }
            if suffix.isEmpty { context.append(word); context = Array(context.suffix(4)) }
            else { context.removeAll() }
            let renderedNepali = result.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) }
            let terminal = suffix.contains("!") || suffix.contains("?") || terminalPeriod(in: suffix, word: word) != nil
            sentenceHasNepali = terminal ? false : (sentenceHasNepali || renderedNepali)
        } else {
            context.removeAll()
            sentenceHasNepali = false
        }
        roman = ""; selection = 0
        codeBeforeToken = keepLiteralState ? nextCodeState : false
        return result
    }
    public mutating func cancel() -> String? {
        guard isComposing else { return nil }
        let original = roman
        roman = ""; selection = 0; context.removeAll(); codeBeforeToken = false; sentenceHasNepali = false
        return original
    }
    public mutating func reset() { roman = ""; selection = 0; context.removeAll(); codeBeforeToken = false; sentenceHasNepali = false }
    public mutating func setLanguage(_ value: TypingLanguage) { reset(); language = value }
    /// Call after committing any marked text so switching cannot discard it.
    public mutating func toggleLanguage() {
        setLanguage(language == .nepali ? .english : .nepali)
    }
}
