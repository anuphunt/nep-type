import Foundation

public struct CompositionSnapshot: Equatable, Sendable {
    public var source = ""
    public var language: TypingLanguage = .nepali
    public var overrides: [Int: String] = [:]
    public init() {}
}

public struct Composer: Sendable {
    public private(set) var state = CompositionSnapshot()
    private var past: [CompositionSnapshot] = []
    private var future: [CompositionSnapshot] = []
    public let engine = Transliterator()
    public init() {}
    public var output: String { engine.render(state.source, language: state.language, overrides: state.overrides) }
    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }

    private mutating func checkpoint() {
        past.append(state)
        if past.count > 200 { past.removeFirst() }
        future.removeAll()
    }

    public mutating func setSource(_ value: String) {
        guard value != state.source else { return }
        checkpoint()
        if !state.overrides.isEmpty {
            let oldUnits = Array(state.source.utf16), newUnits = Array(value.utf16)
            let prefix = zip(oldUnits, newUnits).prefix { $0 == $1 }.count
            var suffix = 0
            while suffix < oldUnits.count - prefix && suffix < newUnits.count - prefix &&
                    oldUnits[oldUnits.count - 1 - suffix] == newUnits[newUnits.count - 1 - suffix] {
                suffix += 1
            }
            let oldWords = engine.tokens(in: state.source)
            let newWords = engine.tokens(in: value)
            let oldByPosition = Dictionary(uniqueKeysWithValues: oldWords.map { ($0.range.location, $0) })
            let newByPosition = Dictionary(uniqueKeysWithValues: newWords.map { ($0.range.location, $0) })
            func counts(_ words: [WordToken]) -> [String: Int] {
                words.filter { !$0.isLiteral }.reduce(into: [:]) { $0[$1.text.lowercased(), default: 0] += 1 }
            }
            let oldCounts = counts(oldWords), newCounts = counts(newWords)
            let suffixStart = oldUnits.count - suffix
            let delta = newUnits.count - oldUnits.count
            var retained: [Int: String] = [:]
            for (position, selected) in state.overrides {
                guard let oldWord = oldByPosition[position], !oldWord.isLiteral,
                      oldCounts[oldWord.text.lowercased()] == newCounts[oldWord.text.lowercased()] else { continue }
                let newPosition: Int
                if NSMaxRange(oldWord.range) <= prefix { newPosition = position }
                else if oldWord.range.location >= suffixStart { newPosition = position + delta }
                else { continue }
                guard newPosition >= 0, let newWord = newByPosition[newPosition],
                      !newWord.isLiteral, newWord.text == oldWord.text,
                      newWord.range.length == oldWord.range.length else { continue }
                retained[newPosition] = selected
            }
            state.overrides = retained
        }
        state.source = value
    }

    public mutating func setLanguage(_ language: TypingLanguage) {
        guard language != state.language else { return }
        checkpoint()
        state.language = language
    }

    public mutating func choose(_ candidate: String, for token: WordToken) {
        guard state.language != .english, !token.isLiteral,
              engine.tokens(in: state.source).contains(token),
              engine.candidates(for: token.text).contains(candidate),
              state.overrides[token.range.location] != candidate else { return }
        checkpoint()
        state.overrides[token.range.location] = candidate
    }

    public mutating func undo() {
        guard let previous = past.popLast() else { return }
        future.append(state)
        state = previous
    }

    public mutating func redo() {
        guard let next = future.popLast() else { return }
        past.append(state)
        state = next
    }
}
