import Foundation
import CNepTypeEngine

/// Resource identity only. Dictionary bytes and lookup live in the Rust library.
public final class EngineDictionaries: Sendable {
    public static let bundled = EngineDictionaries()
    private init() {}
    public init(directory: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw CocoaError(.fileNoSuchFile) }
    }
    public var identifier: String { String(cString: neptype_dictionary_id()) }
}

enum RustEngine {
    static func query(_ request: [String: Any], composer: UnsafeMutableRawPointer? = nil) -> Any {
        let data = try! JSONSerialization.data(withJSONObject: request, options: [.sortedKeys, .fragmentsAllowed])
        let response = String(decoding: data, as: UTF8.self).withCString { pointer in
            if let composer { return neptype_composer_query(composer, pointer) }
            return neptype_engine_query(pointer)
        }
        guard let response else { preconditionFailure("The shared Rust engine rejected an adapter request") }
        defer { neptype_string_destroy(response) }
        return try! JSONSerialization.jsonObject(with: Data(bytes: response, count: strlen(response)), options: [.fragmentsAllowed])
    }
    static func object(_ value: Any) -> [String: Any] { value as! [String: Any] }
    static func mode(_ language: TypingLanguage) -> Int { language == .english ? 1 : language == .allNepali ? 2 : 0 }
    static func language(_ mode: Int) -> TypingLanguage { mode == 1 ? .english : mode == 2 ? .allNepali : .nepali }
    static func encode(_ value: Any) -> Data { try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) }
    static func decode(_ data: Data) -> [String: Any] { object(try! JSONSerialization.jsonObject(with: data)) }
    static func token(_ value: [String: Any]) -> WordToken {
        let start = value["start"] as! Int, end = value["end"] as! Int
        return WordToken(text: value["text"] as! String, range: NSRange(location: start, length: end-start), isLiteral: value["literal"] as! Bool)
    }
    static func token(_ value: WordToken) -> [String: Any] { ["text":value.text,"start":value.range.location,"end":NSMaxRange(value.range),"literal":value.isLiteral] }
}
