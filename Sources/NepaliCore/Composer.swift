import Foundation
import CNepTypeEngine

public struct CompositionSnapshot: Equatable, Sendable {
    public var source = ""
    public var language: TypingLanguage = .nepali
    public var overrides: [Int:String] = [:]
    public init() {}
}
/// Reference-counted foreign handle; Swift copies clone Rust state on mutation.
private final class RustComposerBox: @unchecked Sendable {
    let handle: UnsafeMutableRawPointer
    init(handle: UnsafeMutableRawPointer? = nil) { self.handle = handle ?? neptype_composer_create()! }
    func clone() -> RustComposerBox { RustComposerBox(handle: neptype_composer_clone(handle)) }
    deinit { neptype_engine_destroy(handle) }
}
/// Native editor history stays inside Rust and preserves Swift value semantics.
public struct Composer: Sendable {
    private var box = RustComposerBox()
    private var cached: Data?
    public let engine: Transliterator
    public init(engine: Transliterator = Transliterator()) { self.engine = engine }
    private var response: [String:Any] { cached.map(RustEngine.decode) ?? RustEngine.query(["op":"composer"], composer:box.handle) as! [String:Any] }
    public var state: CompositionSnapshot {
        let current=(response["state"] as! [String:Any])["current"] as! [String:Any]
        var s=CompositionSnapshot();s.source=current["source"] as! String;s.language=RustEngine.language(current["mode"] as! Int)
        s.overrides=Dictionary(uniqueKeysWithValues:(current["overrides"] as! [String:String]).compactMap{key,value in Int(key).map{($0,value)}})
        return s
    }
    public var output: String { (response["rendered"] as! [String:Any])["text"] as! String }
    public var canUndo: Bool { response["canUndo"] as! Bool }
    public var canRedo: Bool { response["canRedo"] as! Bool }
    private mutating func change(_ action: [String:Any]) {
        if !isKnownUniquelyReferenced(&box) { box = box.clone() }
        let r=RustEngine.query(["op":"composer","actions":[action]], composer:box.handle)
        cached=RustEngine.encode(r)
    }
    public mutating func setSource(_ value: String) { change(["op":"source","text":value]) }
    public mutating func setLanguage(_ value: TypingLanguage) { change(["op":"mode","mode":RustEngine.mode(value)]) }
    public mutating func choose(_ candidate: String, for token: WordToken) { change(["op":"choose","token":RustEngine.token(token),"value":candidate]) }
    public mutating func undo() { change(["op":"undo"]) }
    public mutating func redo() { change(["op":"redo"]) }
}
