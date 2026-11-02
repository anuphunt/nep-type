import Foundation
struct Row: Decodable { let input: String; let expected: String }
let rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let engine = Transliterator()
let result = rows.map { row -> [String: Any] in
 let choice = engine.contextChoices(in: row.input).first!
 let candidates = engine.contextualCandidates(for: choice)
 let shown = Array(candidates.prefix(4)) + (candidates.prefix(4).contains(row.input) ? [] : [row.input])
 return ["input": row.input, "expected": row.expected, "top":choice.preferred, "shown":shown, "available":shown.contains(row.expected)]
}
let data=try JSONSerialization.data(withJSONObject: result,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]);FileHandle.standardOutput.write(data)
