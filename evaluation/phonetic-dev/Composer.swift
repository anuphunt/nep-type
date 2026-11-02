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
        let old = Array(state.source.utf16)
        let new = Array(value.utf16)
        let common = zip(old, new).prefix { $0 == $1 }.count
        // Drop choices from the edited word onwards; earlier words keep their choices.
        let affected = engine.tokens(in: state.source).first { NSMaxRange($0.range) >= common }?.range.location ?? common
        state.overrides = state.overrides.filter { $0.key < affected }
        state.source = value
    }

    public mutating func setLanguage(_ language: TypingLanguage) {
        guard language != state.language else { return }
        checkpoint()
        state.language = language
    }

    public mutating func choose(_ candidate: String, for token: WordToken) {
        guard state.language == .nepali, !token.isLiteral,
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
