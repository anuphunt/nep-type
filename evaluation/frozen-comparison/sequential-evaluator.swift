import Foundation

// Approximate InputSession's word-at-a-time core, not native IMK delivery.
// A final implicit boundary is used to score the last visible token.
struct Corpus: Decodable { let version: String; let cases: [Example] }
struct Example: Decodable { let id: String; let category: String; let input: String; let expected: [String] }
func normal(_ s: String) -> String { s.precomposedStringWithCanonicalMapping }
guard CommandLine.arguments.count == 2 else { exit(1) }
let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
var summary: [String: [String: Int]] = [:]
var detail: [[String: Any]] = []
for item in corpus.cases {
    var session = InputSession()
    var output = ""
    for character in item.input {
        let value = String(character)
        if session.append(value) { continue }
        let whitespace = value.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
        if whitespace {
            if let committed = session.commit(keepContext: value == " ", keepLiteralState: true) { output += committed }
        } else {
            if let original = session.cancel() { output += original }
            session.reset()
        }
        output += value
    }
    if let committed = session.commit() { output += committed }
    let exact = item.expected.contains { normal($0) == normal(output) }
    summary[item.category, default: [:]]["total", default: 0] += 1
    if exact { summary[item.category, default: [:]]["exact", default: 0] += 1 }
    detail.append(["id": item.id, "category": item.category, "input": item.input, "expected": item.expected, "actual": output, "exact": exact])
}
let result: [String: Any] = ["fixture_version":corpus.version,"method":"InputSession per-character, boundaries commit; final implicit boundary; no native host, selection, focus or undo", "summary":summary, "cases":detail]
let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes])
FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data("\n".utf8))
