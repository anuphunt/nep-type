import Foundation

/// Local, bounded product state. Nothing in this store is an analytics property.
public final class LocalExperience {
    public struct Draft: Codable {
        public var source: String
        public var mode: String
        public var choices: [Int:String]
    }
    private let defaults: UserDefaults
    private let draftURL: URL?
    private let key = "neptype.experience.v1."
    public init(defaults: UserDefaults = .standard, directory: URL? = nil, persistent: Bool = true) {
        self.defaults = defaults
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "app.neptype.pad", isDirectory: true)
        draftURL = persistent ? root?.appendingPathComponent("draft-v1.json") : nil
    }
    public var spellings: [String:String] {
        (defaults.dictionary(forKey: key + "spellings") as? [String:String] ?? [:])
            .filter { Self.validRoman($0.key) && $0.value.utf8.count <= 1024 }
    }
    public func remember(_ roman: String, value: String, candidates: [String]) {
        guard Self.validRoman(roman), candidates.contains(value), let first = candidates.first else { return }
        var values = spellings
        let key = roman.lowercased()
        if value == first { values.removeValue(forKey: key) }
        else {
            if values.count >= 256, values[key] == nil { values.removeValue(forKey: values.keys.sorted().first!) }
            values[key] = value
        }
        defaults.set(values, forKey: self.key + "spellings")
    }
    public func resetSpellings() { defaults.removeObject(forKey: key + "spellings") }
    private static func validRoman(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 64 && value.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) }
    }
    public func loadDraft() -> Draft? {
        guard let url = draftURL, let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 2_000_000, let data = try? Data(contentsOf: url),
              let draft = try? JSONDecoder().decode(Draft.self, from: data), draft.source.utf8.count <= 1_048_576,
              ["nepali", "allNepali", "english"].contains(draft.mode), draft.choices.count <= 2048 else { return nil }
        return draft
    }
    @discardableResult public func saveDraft(_ state: CompositionSnapshot) -> Bool {
        guard let url = draftURL else { return true }
        if state.source.isEmpty { return clearDraft() }
        guard state.source.utf8.count <= 1_048_576 else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let draft = Draft(source: state.source, mode: state.language.rawValue, choices: state.overrides)
            let data = try JSONEncoder().encode(draft)
            #if os(iOS)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            #else
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            #endif
            var protected = url
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try protected.setResourceValues(values)
            return true
        } catch { return false }
    }
    @discardableResult public func clearDraft() -> Bool {
        guard let url = draftURL, FileManager.default.fileExists(atPath: url.path) else { return true }
        do { try FileManager.default.removeItem(at: url); return true } catch { return false }
    }
    public func restore(into composer: inout Composer) -> Bool {
        composer.setPreferredSpellings(spellings)
        guard let draft = loadDraft() else { return false }
        composer.setLanguage(TypingLanguage(rawValue: draft.mode) ?? .nepali)
        composer.setSource(draft.source)
        for token in composer.engine.tokens(in: draft.source) where !token.isLiteral {
            if let choice = draft.choices[token.range.location] { composer.choose(choice, for: token) }
        }
        return true
    }
}
