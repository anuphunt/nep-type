import Foundation

struct Corpus: Decodable { let cases: [Example] }
struct Example: Decodable { let id: String; let input: String; let expected: [String] }
func normal(_ text: String) -> String { text.precomposedStringWithCanonicalMapping }
func sequential(_ source: String) -> String {
    var state = InputSession()
    var output = ""
    for character in source {
        let text = String(character)
        if state.append(text) { continue }
        let whitespace = text.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
        if let committed = state.commit(keepContext: text == " ", keepLiteralState: whitespace) { output += committed }
        if !whitespace { state.reset() }
        output += text
    }
    if let committed = state.commit() { output += committed }
    return output
}
let path = CommandLine.arguments[1]
let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
let engine = Transliterator()
var padMatches = 0, sequentialMatches = 0, different = 0
var details: [[String: Any]] = []
for item in corpus.cases {
    let pad = engine.render(item.input), live = sequential(item.input)
    let padOK = item.expected.contains { normal($0) == normal(pad) }
    let liveOK = item.expected.contains { normal($0) == normal(live) }
    if padOK { padMatches += 1 }; if liveOK { sequentialMatches += 1 }; if pad != live { different += 1 }
    details.append(["id": item.id, "input": item.input, "expected": item.expected, "pad": pad, "sequential": live, "pad_exact": padOK, "sequential_exact": liveOK])
}
let result: [String: Any] = ["cases": corpus.cases.count, "pad_exact": padMatches, "sequential_exact": sequentialMatches, "different_outputs": different, "caveat": "Previously inspected synthetic corpus, not independent accuracy. Sequential state simulation does not exercise a real host, focus, key events, or candidate UI.", "details": details]
let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
FileHandle.standardOutput.write(data)
