import Foundation

public enum TypingLanguage: String, Sendable { case nepali, english }

public struct WordToken: Equatable, Sendable {
    public let text: String
    public let range: NSRange
    public let isLiteral: Bool
}

/// Offline, deterministic transliteration. The small lexicon is hand-authored;
/// the fallback is phonetic, not a trained language model or a translator.
public struct Transliterator: Sendable {
    public init() {}

    private static let lexicon = GeneratedIndexes.nepali

    /// Dictionary membership is evidence, not a language decision.
    public func isKnownEnglish(_ word: String) -> Bool {
        GeneratedIndexes.englishWords.contains(word.lowercased())
    }

    private static let english: Set<String> = [
        "office", "meeting", "zoom", "email", "gmail", "google", "apple", "mac", "macbook",
        "iphone", "android", "laptop", "computer", "keyboard", "app", "apps", "code", "swift",
        "python", "javascript", "website", "internet", "wifi", "hello", "hi", "hey", "thanks",
        "thank", "you", "please", "sorry", "yes", "no", "ok", "okay", "the", "is", "are",
        "and", "this", "that", "my", "your", "with", "for", "from", "to", "of", "in", "on",
        "at", "work", "today", "tomorrow", "lunch", "dinner", "coffee", "project", "prototype",
        "test", "link", "file", "pdf", "team", "call", "message", "send", "online", "offline",
        "facebook", "instagram", "youtube", "whatsapp", "viber", "chatgpt", "ai", "english",
        "soccer", "cricket", "basketball", "volleyball", "sport", "sports", "game", "games",
        "player", "players", "match", "team", "goal", "win", "world", "cup", "league", "club"
    ]

    public func tokens(in source: String) -> [WordToken] {
        // A literal is matched before ordinary words, so its interior is never converted.
        let pattern = #"https?://[^\s]+|www\.[^\s]+|[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}|`[^`]*`|[A-Za-z]+"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let ns = source as NSString
        return regex.matches(in: source, range: NSRange(location: 0, length: ns.length)).map {
            let word = ns.substring(with: $0.range)
            let literal = word.contains("://") || word.lowercased().hasPrefix("www.") || word.contains("@") || word.hasPrefix("`")
            return WordToken(text: word, range: $0.range, isLiteral: literal)
        }
    }

    public func activeToken(in source: String, caret: Int) -> WordToken? {
        tokens(in: source).first { !$0.isLiteral && caret >= $0.range.location && caret <= NSMaxRange($0.range) }
    }

    private func baseCandidates(for input: String) -> [String] {
        let key = input.lowercased()
        guard !key.isEmpty else { return [] }
        var choices = Self.lexicon[key] ?? []
        if Self.english.contains(key) || (input.count > 1 && input == input.uppercased()) {
            choices.insert(input, at: 0)
        }
        choices.append(phonetic(key))
        choices.append(input)
        var seen = Set<String>()
        return choices.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Lower-confidence pronunciation-derived alternatives, in lexical order, not frequency.
    public func experimentalCandidates(for input: String) -> [String] {
        let existing = Set(baseCandidates(for: input))
        return GeneratedAliasIndex.lookup(input.lowercased()).filter { !existing.contains($0) }
    }

    /// Aksharantar IndicCorp-sourced alternatives; commercial rights review is pending.
    public func aksharantarCandidates(for input: String) -> [String] {
        let existing = Set(baseCandidates(for: input))
        return GeneratedAliasIndex.aksharantarLookup(input.lowercased()).filter { !existing.contains($0) }
    }

    public func candidates(for input: String) -> [String] {
        let base = baseCandidates(for: input)
        guard !base.isEmpty else { return [] }
        let original = base.last == input ? base.dropLast() : base[...]
        var result = Array(original)
        var seen = Set(result)
        // Source-derived, lexically ordered Aksharantar candidates are suggestions only.
        for candidate in aksharantarCandidates(for: input) where candidate != input {
            if seen.insert(candidate).inserted { result.append(candidate) }
        }
        for candidate in experimentalCandidates(for: input) where candidate != input {
            if seen.insert(candidate).inserted { result.append(candidate) }
        }
        if seen.insert(input).inserted { result.append(input) }
        return result
    }

    public func render(_ source: String, language: TypingLanguage = .nepali, overrides: [Int: String] = [:]) -> String {
        guard language == .nepali else { return source }
        let result = NSMutableString(string: source)
        for token in tokens(in: source).reversed() where !token.isLiteral {
            result.replaceCharacters(in: token.range, with: overrides[token.range.location] ?? baseCandidates(for: token.text).first ?? token.text)
        }
        return result as String
    }

    public func phonetic(_ input: String) -> String {
        let chars = Array(input.lowercased())
        let consonants: [String: String] = [
            "ksh":"क्ष", "chh":"छ", "gy":"ज्ञ", "jn":"ज्ञ", "kh":"ख", "gh":"घ",
            "ch":"च", "jh":"झ", "th":"थ", "dh":"ध", "ph":"फ", "bh":"भ",
            "sh":"श", "ng":"ङ", "ny":"ञ", "k":"क", "g":"ग", "c":"च",
            "j":"ज", "t":"त", "d":"द", "n":"न", "p":"प", "b":"ब",
            "m":"म", "y":"य", "r":"र", "l":"ल", "w":"व", "v":"व",
            "s":"स", "h":"ह", "f":"फ", "q":"क", "x":"क्स", "z":"ज"
        ]
        let vowels: [String: (String, String)] = [
            "aa":("आ","ा"), "ai":("ऐ","ै"), "au":("औ","ौ"),
            "ee":("ई","ी"), "ii":("ई","ी"), "oo":("ऊ","ू"), "uu":("ऊ","ू"),
            "a":("अ",""), "i":("इ","ि"), "u":("उ","ु"), "e":("ए","े"), "o":("ओ","ो")
        ]
        func match<T>(_ table: [String: T], at index: Int) -> (T, Int)? {
            guard index < chars.count else { return nil }
            for length in stride(from: min(3, chars.count - index), through: 1, by: -1) {
                if let value = table[String(chars[index..<(index + length)])] { return (value, length) }
            }
            return nil
        }
        var output = ""
        var i = 0
        while i < chars.count {
            if let (consonant, length) = match(consonants, at: i) {
                output += consonant
                i += length
                if let (vowel, vowelLength) = match(vowels, at: i) {
                    output += vowel.1
                    i += vowelLength
                } else if i < chars.count, match(consonants, at: i) != nil {
                    output += "्"
                }
            } else if let (vowel, length) = match(vowels, at: i) {
                output += vowel.0
                i += length
            } else {
                output.append(chars[i])
                i += 1
            }
        }
        return output
    }
}
