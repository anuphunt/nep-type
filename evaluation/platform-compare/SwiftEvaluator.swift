import Foundation

// The fixture is authored separately and is not used to tune the engine.
// It remains synthetic and its labels have not been reviewed by a speaker.
struct Corpus: Decodable { let version: String; let cases: [Example] }
struct Example: Decodable { let id: String; let category: String; let input: String; let expected: [String]; let annotations: [Annotation] }
struct Annotation: Decodable { let token: String; let role: String; let acceptable: [String] }
func normal(_ s: String) -> String { s.precomposedStringWithCanonicalMapping }
func match(_ values: [String], _ value: String) -> Bool { values.contains { normal($0) == normal(value) } }
func fail(_ value: String) -> Never { FileHandle.standardError.write(Data((value + "\n").utf8)); exit(1) }
guard CommandLine.arguments.count == 2 else { fail("Usage: heldout-eval fixture.json") }
let fixture = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let engine = Transliterator()
var summary: [String: [String: Int]] = [:]
var details: [[String: Any]] = []
var ids = Set<String>()
func increment(_ category: String, _ key: String) { summary[category, default: [:]][key, default: 0] += 1 }
for item in fixture.cases {
    guard ids.insert(item.id).inserted, !item.expected.isEmpty else { fail("Invalid id/expected: \(item.id)") }
    let choices = engine.contextChoices(in: item.input)
    let actual = engine.render(item.input)
    var nextChoice = 0
    var rows: [[String: Any]] = []
    for annotation in item.annotations {
        guard ["english", "nepali", "literal"].contains(annotation.role), !annotation.acceptable.isEmpty else { fail("\(item.id): invalid annotation \(annotation.token)") }
        // Annotations are selective and ordered. Skipped tokens carry no score.
        let index = (nextChoice..<choices.count).first { choices[$0].token.text == annotation.token }
        if index == nil && annotation.role == "literal" {
            // Non-tokenized spans such as emoji have no engine choice. This
            // checks containment, not positional preservation within the host.
            guard item.input.contains(annotation.token) else { fail("\(item.id): literal span absent from input") }
            let preserved = annotation.acceptable.contains { actual.contains($0) }
            increment(item.category, "literal_total")
            if preserved { increment(item.category, "literal_correct"); increment(item.category, "literal_candidate_available") }
            rows.append(["input":annotation.token,"role":"literal","expected":annotation.acceptable,"actual":"containment check","correct":preserved,"candidate_available":preserved])
            continue
        }
        guard let index else { fail("\(item.id): annotation absent or out of order: \(annotation.token)") }
        let choice = choices[index]
        nextChoice = index + 1
        let all = choice.token.isLiteral ? [choice.token.text] : engine.contextualCandidates(for: choice)
        guard let top = all.first else { fail("\(item.id): missing candidate") }
        var visible = Array(all.prefix(4)); if !visible.contains(choice.token.text) { visible.append(choice.token.text) }
        let correct = match(annotation.acceptable, top)
        let available = annotation.acceptable.contains { match(visible, $0) }
        increment(item.category, annotation.role + "_total")
        if correct { increment(item.category, annotation.role + "_correct") }
        if available { increment(item.category, annotation.role + "_candidate_available") }
        rows.append(["input":annotation.token,"role":annotation.role,"expected":annotation.acceptable,"actual":top,"correct":correct,"candidate_available":available])
    }
    let exact = match(item.expected, actual)
    increment(item.category, "sentences_total")
    if exact { increment(item.category, "sentences_exact") }
    details.append(["id":item.id,"category":item.category,"input":item.input,"expected":item.expected,"actual":actual,"exact":exact,"tokens":rows])
}
let output: [String: Any] = ["fixture_version":fixture.version,"method":"Context-ranked top choice, canonical Unicode equality, four candidates plus original; standalone engine only", "summary":summary, "cases":details]
let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes])
FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data("\n".utf8))
