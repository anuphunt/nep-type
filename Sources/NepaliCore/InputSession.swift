import Foundation

/// Swift transport and value semantics; Rust owns composition and context state.
public struct InputSession: Sendable {
    private var payload = Data("{}".utf8)
    public init(engine: Transliterator = Transliterator()) { _ = engine }
    private var response: [String:Any] { RustEngine.query(["op":"session","state":RustEngine.decode(payload)]) as! [String:Any] }
    private var state: [String:Any] { response["state"] as! [String:Any] }
    public var roman: String { state["roman"] as! String }
    public var context: [String] { state["context"] as! [String] }
    public var selection: Int { state["selection"] as! Int }
    public var language: TypingLanguage { RustEngine.language(state["mode"] as! Int) }
    public var isComposing: Bool { !roman.isEmpty }
    public var candidates: [String] { response["candidates"] as! [String] }
    public var markedText: String { response["markedText"] as! String }
    private mutating func change(_ action: [String:Any]) -> [String:Any] {
        let r=RustEngine.query(["op":"session","state":RustEngine.decode(payload),"actions":[action]]) as! [String:Any]
        payload=RustEngine.encode(r["state"]!)
        return (r["trace"] as! [[String:Any]]).first!
    }
    public mutating func append(_ text: String) -> Bool { change(["op":"append","text":text])["accepted"] as! Bool }
    public mutating func backspace() -> Bool { change(["op":"backspace"])["accepted"] as! Bool }
    public mutating func cycle(_ delta: Int) { _ = change(["op":"cycle","delta":delta]) }
    public mutating func select(_ value: String) -> Bool { change(["op":"select","text":value])["accepted"] as! Bool }
    public mutating func commit(keepContext: Bool = false, keepLiteralState: Bool = false) -> String? { change(["op":"commit","keepContext":keepContext,"keepLiteralState":keepLiteralState])["result"] as? String }
    public mutating func cancel() -> String? { change(["op":"cancel"])["result"] as? String }
    public mutating func reset() { _ = change(["op":"reset"]) }
    public mutating func setLanguage(_ value: TypingLanguage) { _ = change(["op":"setMode","mode":RustEngine.mode(value)]) }
    public mutating func toggleLanguage() { setLanguage(language == .nepali ? .english : .nepali) }
}
