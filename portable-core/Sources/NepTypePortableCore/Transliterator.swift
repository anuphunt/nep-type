import Foundation

public enum TypingLanguage: String, Sendable { case nepali, english, allNepali }

public struct WordToken: Equatable, Sendable {
    public let text: String
    public let range: NSRange
    public let isLiteral: Bool
}

/// Exact UTF-16 ranges for words in the rendered output and their source.
public struct RenderedWord: Equatable, Sendable {
    public let source: WordToken
    public let outputRange: NSRange
}
public struct RenderedText: Sendable {
    public let text: String
    public let words: [RenderedWord]
}

public struct ContextChoice: Equatable, Sendable {
    public let token: WordToken
    public let preferred: String
    public let uncertain: Bool
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
        // Protect incomplete code while the user is still entering it, as well
        // as common identifiers. These checks apply to the standalone pad;
        // an input method composing one word at a time needs separate safeguards.
        let pattern = #"(?s:```(?:.*?```|.*\z))|(?i:https?://[^\s]+|www\.[^\s]+|[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})|`[^`\n]*(?:`|(?=\n|\z))|(?:[A-Za-z0-9._~\-]+/)+[A-Za-z0-9._~\-]+|[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+|(?:[A-Za-z_][A-Za-z0-9_]*[0-9_][A-Za-z0-9_]*|[0-9]+[A-Za-z_][A-Za-z0-9_]*)|[a-z]+[A-Z][A-Za-z]*|[A-Za-z]+(?:['’_-][A-Za-z]+)+|[A-Za-z]+"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = source as NSString
        return regex.matches(in: source, range: NSRange(location: 0, length: ns.length)).map {
            let word = ns.substring(with: $0.range)
            let isMixedCaseIdentifier = word.first?.isLowercase == true && word.dropFirst().contains(where: { $0.isUppercase })
            let literal = word.contains("://") || word.lowercased().hasPrefix("www.") || word.contains("@") || word.hasPrefix("`") || word.contains("'") || word.contains("’") || word.contains("-") || word.contains("_") || word.contains(".") || word.contains("/") || word.contains(where: { $0.isNumber }) || isMixedCaseIdentifier
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
        let acronym = input.count > 1 && input == input.uppercased()
        // Curated Nepali words are explicit overrides. Otherwise, an English
        // dictionary hit is ambiguous, so preserve it instead of converting it.
        if Self.english.contains(key) || acronym || (choices.isEmpty && isKnownEnglish(input) && GeneratedAliasIndex.lookup(key).isEmpty) {
            choices.insert(input, at: 0)
        } else if choices.isEmpty {
            let matches = GeneratedAliasIndex.aksharantarLookup(key)
            // An exact single match is useful evidence, not a guarantee of intent.
            // Multiple spellings stay suggestions rather than choosing alphabetically.
            if key.count >= 3, matches.count == 1 { choices.append(matches[0]) }
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

    public func usesAksharantarAsDefault(for input: String) -> Bool {
        let key = input.lowercased()
        guard key.count >= 3, Self.lexicon[key] == nil else { return false }
        let matches = GeneratedAliasIndex.aksharantarLookup(key)
        return matches.count == 1 && baseCandidates(for: input).first == matches[0]
    }

    public func candidates(for input: String) -> [String] {
        let base = baseCandidates(for: input)
        guard !base.isEmpty else { return [] }
        let original = base.last == input ? base.dropLast() : base[...]
        var result = Array(original)
        var seen = Set(result)
        // Additional source-derived, lexically ordered candidates are suggestions.
        for candidate in aksharantarCandidates(for: input) where candidate != input {
            if seen.insert(candidate).inserted { result.append(candidate) }
        }
        for candidate in experimentalCandidates(for: input) where candidate != input {
            if seen.insert(candidate).inserted { result.append(candidate) }
        }
        if seen.insert(input).inserted { result.append(input) }
        return result
    }

    /// Hand-authored local evidence scores, not calibrated probabilities.
    /// Neighbor evidence never crosses punctuation, newlines or literal tokens.
    public func contextChoices(in source: String) -> [ContextChoice] {
        let words = tokens(in: source)
        let ns = source as NSString
        struct Evidence { let english: Int; let nepali: Int; let englishAnchor: Bool; let nepaliAnchor: Bool; let preferredNepali: String? }
        let evidence: [Evidence] = words.map { word in
            let key = word.text.lowercased()
            if word.isLiteral { return Evidence(english: 0, nepali: 0, englishAnchor: false, nepaliAnchor: false, preferredNepali: nil) }
            let curated = Self.lexicon[key]
            let commonEnglish = Self.english.contains(key)
            let knownEnglish = commonEnglish || isKnownEnglish(key)
            let matches = GeneratedAliasIndex.aksharantarLookup(key)
            // A broad English dictionary includes many Nepali romanizations
            // and names; treat that as weak evidence when we have a curated word.
            let english = commonEnglish ? 5 : (knownEnglish ? (curated == nil ? 3 : 1) : 0)
            let nepali = curated != nil ? 5 : (matches.count == 1 && key.count >= 3 ? 4 : 0)
            let englishAnchor = commonEnglish && curated == nil
            let nepaliAnchor = curated != nil && !commonEnglish
            return Evidence(english: english, nepali: nepali, englishAnchor: englishAnchor, nepaliAnchor: nepaliAnchor, preferredNepali: curated?.first ?? (matches.count == 1 && key.count >= 3 ? matches.first : nil))
        }
        func contiguous(_ a: Int, _ b: Int) -> Bool {
            guard a >= 0, b < words.count, !words[a].isLiteral, !words[b].isLiteral else { return false }
            let start = NSMaxRange(words[a].range), end = words[b].range.location
            guard end >= start else { return false }
            let gap = ns.substring(with: NSRange(location: start, length: end - start))
            return !gap.isEmpty && gap.unicodeScalars.allSatisfy { $0 == " " || $0 == "\t" }
        }
        return words.indices.map { index in
            let word = words[index], item = evidence[index]
            if word.isLiteral { return ContextChoice(token: word, preferred: word.text, uncertain: false) }
            if word.text.count > 1 && word.text == word.text.uppercased() { return ContextChoice(token: word, preferred: word.text, uncertain: false) }
            // Words explicitly known in both languages are ambiguous even in
            // a Nepali sentence (e.g. a borrowed sports term). Preserve the
            // typed form and offer the curated Nepali spelling as a choice.
            let key = word.text.lowercased()
            if Self.english.contains(key), Self.lexicon[key] != nil {
                return ContextChoice(token: word, preferred: word.text, uncertain: true)
            }
            var e = item.english, n = item.nepali
            if index > 0 && contiguous(index - 1, index) { if evidence[index - 1].englishAnchor { e += 3 }; if evidence[index - 1].nepaliAnchor { n += 3 } }
            if index + 1 < words.count && contiguous(index, index + 1) { if evidence[index + 1].englishAnchor { e += 3 }; if evidence[index + 1].nepaliAnchor { n += 3 } }
            if index > 0 && contiguous(index - 1, index), ["the", "a", "an"].contains(words[index - 1].text.lowercased()), item.english > 0 { e += 4 }
            // Do not let neighbors manufacture a word when the token has no
            // English or Nepali evidence of its own.
            if item.english == 0 && item.nepali == 0 { return ContextChoice(token: word, preferred: phonetic(word.text), uncertain: true) }
            if e >= n + 2 && item.english > 0 { return ContextChoice(token: word, preferred: word.text, uncertain: false) }
            if (n >= e + 2 || (Self.lexicon[key] != nil && n > e)), let native = item.preferredNepali {
                // Language evidence does not resolve word sense or spelling.
                // Expose authored alternatives as uncertain so the user can
                // review them (e.g. पानी / पनि), even when Nepali is likely.
                let authoredAlternatives = Set(Self.lexicon[key] ?? [])
                return ContextChoice(token: word, preferred: native, uncertain: authoredAlternatives.count > 1)
            }
            return ContextChoice(token: word, preferred: word.text, uncertain: true)
        }
    }

    public func contextualCandidates(for choice: ContextChoice) -> [String] {
        let alternatives = candidates(for: choice.token.text)
        guard alternatives.contains(choice.preferred) else { return alternatives }
        return [choice.preferred] + alternatives.filter { $0 != choice.preferred }
    }

    /// All-Nepali mode keeps protected literals but prefers a Devanagari
    /// alternative even for English words. This is transliteration, not translation.
    public func contextChoices(in source: String, language: TypingLanguage) -> [ContextChoice] {
        let choices = contextChoices(in: source)
        guard language == .allNepali else { return choices }
        return choices.map { choice in
            guard !choice.token.isLiteral else { return choice }
            let devanagari: (String) -> Bool = { $0.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) } }
            if devanagari(choice.preferred) { return choice }
            let converted = candidates(for: choice.token.text).first(where: devanagari) ?? phonetic(choice.token.text)
            return ContextChoice(token: choice.token, preferred: converted, uncertain: true)
        }
    }

    public func render(_ source: String, language: TypingLanguage = .nepali, overrides: [Int: String] = [:]) -> String {
        renderWithMapping(source, language: language, overrides: overrides).text
    }

    /// Mapping is derived from the exact replacements, including explicit
    /// choices and protected tokens; sentence-stop substitution is length-neutral.
    public func renderWithMapping(_ source: String, language: TypingLanguage = .nepali, overrides: [Int: String] = [:]) -> RenderedText {
        let choices = contextChoices(in: source, language: language)
        let result = NSMutableString(string: source)
        var words: [RenderedWord] = []
        var delta = 0
        for choice in choices {
            let token = choice.token
            let replacement = language == .english || token.isLiteral ? token.text : (overrides[token.range.location] ?? choice.preferred)
            let length = (replacement as NSString).length
            if !token.isLiteral && length > 0 {
                words.append(RenderedWord(source: token, outputRange: NSRange(location: token.range.location + delta, length: length)))
            }
            delta += length - token.range.length
        }
        if language != .english {
            for position in sentenceStopPositions(in: source, choices: choices, overrides: overrides) {
                result.replaceCharacters(in: NSRange(location: position, length: 1), with: "।")
            }
            for choice in choices.reversed() where !choice.token.isLiteral {
                let token = choice.token
                result.replaceCharacters(in: token.range, with: overrides[token.range.location] ?? choice.preferred)
            }
        }
        return RenderedText(text: result as String, words: words)
    }

    /// Replace sentence-ending dots only when the current sentence contains
    /// Nepali output. Preserve protected tokens, decimals, ellipses and common
    /// abbreviations. This deliberately keeps English-only sentences intact.
    private func sentenceStopPositions(in source: String, choices: [ContextChoice], overrides: [Int: String]) -> [Int] {
        let text = source as NSString
        let abbreviations: Set<String> = ["mr", "mrs", "ms", "dr", "prof", "sr", "jr", "st", "vs", "etc"]
        let closers: Set<UInt16> = [34, 39, 41, 93, 125, 0x2019, 0x201D]
        var positions: [Int] = []
        var index = 0, choiceIndex = 0
        var hasNepali = false
        var previous: WordToken?
        while index < text.length {
            if choiceIndex < choices.count, choices[choiceIndex].token.range.location == index {
                let choice = choices[choiceIndex]
                if !choice.token.isLiteral {
                    let rendered = overrides[index] ?? choice.preferred
                    hasNepali = hasNepali || rendered.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) }
                }
                previous = choice.token
                index = NSMaxRange(choice.token.range)
                choiceIndex += 1
                continue
            }
            let char = text.character(at: index)
            if (0x0900...0x097F).contains(char) { hasNepali = true }
            if char == 46 {
                let left = index > 0 ? text.character(at: index - 1) : 0
                let right = index + 1 < text.length ? text.character(at: index + 1) : 0
                if left != 46 && right != 46 {
                    var end = index + 1
                    while end < text.length && closers.contains(text.character(at: end)) { end += 1 }
                    let atBoundary = end == text.length || (UnicodeScalar(text.character(at: end)).map { CharacterSet.whitespacesAndNewlines.contains($0) } ?? false)
                    let adjacent = previous.map { NSMaxRange($0.range) == index } ?? false
                    let abbreviation = adjacent && (previous!.isLiteral || abbreviations.contains(previous!.text.lowercased()))
                    if atBoundary && !abbreviation {
                        if hasNepali { positions.append(index) }
                        hasNepali = false
                    }
                }
            } else if char == 33 || char == 63 || char == 10 || char == 0x0964 {
                hasNepali = false
            }
            index += 1
        }
        return positions
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
