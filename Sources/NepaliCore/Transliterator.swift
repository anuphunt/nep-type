import Foundation

public enum TypingLanguage: String, Sendable { case nepali, english, allNepali }
public struct WordToken: Equatable, Sendable { public let text: String; public let range: NSRange; public let isLiteral: Bool }
public struct RenderedWord: Equatable, Sendable { public let source: WordToken; public let outputRange: NSRange }
public struct RenderedText: Sendable { public let text: String; public let words: [RenderedWord] }
public struct ContextChoice: Equatable, Sendable { public let token: WordToken; public let preferred: String; public let uncertain: Bool }

/// Swift value/type adapter only. Every language decision is made by Rust.
public struct Transliterator: Sendable {
    public init(dictionaries: EngineDictionaries = .bundled) { _ = dictionaries }
    private func call(_ op: String, _ source: String, _ values: [String:Any] = [:]) -> Any {
        RustEngine.query(values.merging(["op":op,"source":source]) { _,new in new })
    }
    public func isKnownEnglish(_ word: String) -> Bool { call("known",word) as! Bool }
    public func tokens(in source: String) -> [WordToken] { (call("tokens",source) as! [[String:Any]]).map(RustEngine.token) }
    public func activeToken(in source: String, caret: Int) -> WordToken? { tokens(in:source).first { !$0.isLiteral && caret >= $0.range.location && caret <= NSMaxRange($0.range) } }
    public func candidates(for input: String) -> [String] { call("candidates",input) as! [String] }
    public func experimentalCandidates(for input: String) -> [String] { call("experimental",input) as! [String] }
    public func aksharantarCandidates(for input: String) -> [String] { call("aksharantar",input) as! [String] }
    public func usesAksharantarAsDefault(for input: String) -> Bool { call("usesAksharantar",input) as! Bool }
    public func phonetic(_ input: String) -> String { call("phonetic",input) as! String }
    public func contextChoices(in source: String) -> [ContextChoice] { contextChoices(in:source,language:.nepali) }
    public func contextChoices(in source: String, language: TypingLanguage) -> [ContextChoice] {
        (call("context",source,["mode":RustEngine.mode(language)]) as! [[String:Any]]).map { ContextChoice(token:RustEngine.token($0["token"] as! [String:Any]), preferred:$0["preferred"] as! String, uncertain:$0["uncertain"] as! Bool) }
    }
    public func contextualCandidates(for choice: ContextChoice) -> [String] {
        RustEngine.query(["op":"contextualCandidates","choice":["token":RustEngine.token(choice.token),"preferred":choice.preferred,"uncertain":choice.uncertain]]) as! [String]
    }
    public func render(_ source: String, language: TypingLanguage = .nepali, overrides: [Int:String] = [:]) -> String { renderWithMapping(source,language:language,overrides:overrides).text }
    public func renderWithMapping(_ source: String, language: TypingLanguage = .nepali, overrides: [Int:String] = [:]) -> RenderedText {
        let values=Dictionary(uniqueKeysWithValues:overrides.map{(String($0.key),$0.value)})
        let r=call("render",source,["mode":RustEngine.mode(language),"overrides":values]) as! [String:Any]
        let words=(r["words"] as! [[String:Any]]).map { value in
            let start=value["outputStart"] as! Int, end=value["outputEnd"] as! Int
            return RenderedWord(source:RustEngine.token(value),outputRange:NSRange(location:start,length:end-start))
        }
        return RenderedText(text:r["text"] as! String,words:words)
    }
}
