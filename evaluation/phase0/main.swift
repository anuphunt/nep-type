import Foundation

struct Corpus: Decodable { let version: String; let cases: [Case] }
struct Case: Decodable { let id: String; let split: String; let source: String; let input: String; let expected: [String]; let annotations: [Annotation] }
struct Annotation: Decodable { let token: String; let role: String; let acceptable: [String] }
func normal(_ s: String) -> String { s.precomposedStringWithCanonicalMapping }
func contains(_ values: [String], _ value: String) -> Bool { values.contains { normal($0) == normal(value) } }
func fail(_ message: String) -> Never { FileHandle.standardError.write(Data("Error: \(message)\n".utf8)); exit(1) }
let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "evaluation/phase0/corpus-v1.json"
let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
let engine = Transliterator()
var ids = Set<String>()
var cases: [[String: Any]] = []
var totals: [String: [String: Int]] = [:]
func increment(_ split: String, _ key: String) { totals[split, default: [:]][key, default: 0] += 1 }
for item in corpus.cases {
    guard ids.insert(item.id).inserted, ["dev", "heldout"].contains(item.split), ["synthetic", "user-example"].contains(item.source), !item.expected.isEmpty else { fail("invalid metadata \(item.id)") }
    let tokens = engine.tokens(in: item.input).filter { !$0.isLiteral }
    guard tokens.count == item.annotations.count else { fail("\(item.id): \(tokens.count) engine tokens but \(item.annotations.count) annotations") }
    var detail: [[String: Any]] = []
    for (token, annotation) in zip(tokens, item.annotations) {
        guard token.text == annotation.token, ["english", "nepali"].contains(annotation.role), !annotation.acceptable.isEmpty else { fail("\(item.id): invalid annotation for \(token.text)") }
        let all = engine.candidates(for: token.text)
        guard let top = all.first else { fail("\(item.id): no candidates for \(token.text)") }
        var visible = Array(all.prefix(4)); if !visible.contains(token.text) { visible.append(token.text) }
        let correct = contains(annotation.acceptable, top)
        let available = annotation.acceptable.contains { contains(visible, $0) }
        increment(item.split, "\(annotation.role)_total")
        if correct { increment(item.split, "\(annotation.role)_correct") }
        if available { increment(item.split, "\(annotation.role)_candidate_available") }
        detail.append(["input": token.text, "role": annotation.role, "expected": annotation.acceptable, "actual": top, "candidates_shown": visible, "correct": correct, "candidate_available": available])
    }
    let actual = engine.render(item.input)
    let exact = contains(item.expected, actual)
    increment(item.split, "sentences_total"); if exact { increment(item.split, "sentences_exact") }
    cases.append(["id":item.id, "split":item.split, "source":item.source, "input":item.input, "expected":item.expected, "actual":actual, "exact":exact, "tokens":detail])
}
let output: [String: Any] = ["corpus_version":corpus.version,"method":"Nepali mode; per-token top candidate and standalone pad visible candidates (first four plus original); canonical Unicode equality; no edits or model tuning", "summary":totals,"cases":cases]
let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data("\n".utf8))
