import Foundation
struct Corpus: Decodable { let version: String; let cases: [Example] }
struct Example: Decodable { let id: String; let category: String; let role: String; let roman: String; let acceptable: [String] }
func normal(_ s: String) -> String { s.precomposedStringWithCanonicalMapping }
guard CommandLine.arguments.count == 2 else { exit(1) }
let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let engine = Transliterator()
var summary: [String: [String: Int]] = [:]
var details: [[String: Any]] = []
for item in corpus.cases {
    guard let choice = engine.contextChoices(in: item.roman).first else { fatalError("missing token \(item.id)") }
    let candidates = engine.contextualCandidates(for: choice)
    guard let top = candidates.first else { fatalError("missing candidates \(item.id)") }
    var visible = Array(candidates.prefix(4)); if !visible.contains(item.roman) { visible.append(item.roman) }
    let expected = Set(item.acceptable.map(normal))
    let topOK = expected.contains(normal(top))
    let shown = visible.contains { expected.contains(normal($0)) }
    let any = candidates.contains { expected.contains(normal($0)) }
    let original = candidates.contains(item.roman)
    summary[item.category, default: [:]]["total", default: 0] += 1
    if topOK { summary[item.category, default: [:]]["top", default: 0] += 1 }
    if shown { summary[item.category, default: [:]]["visible", default: 0] += 1 }
    if any { summary[item.category, default: [:]]["all", default: 0] += 1 }
    if original { summary[item.category, default: [:]]["original", default: 0] += 1 }
    details.append(["id":item.id,"category":item.category,"role":item.role,"roman":item.roman,"expected":item.acceptable,"top":top,"visible":visible,"all":candidates,"top_match":topOK,"visible_match":shown,"all_match":any,"original_available":original])
}
let result: [String: Any] = ["fixture_version":corpus.version,"method":"isolated token, contextual top; first four plus original; no native host", "summary":summary,"cases":details]
let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes])
FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data("\n".utf8))
