import Foundation
let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let rows = try JSONSerialization.jsonObject(with: data) as! [[Any]]
let engine = Transliterator()
var hits = 0, visible = 0, top = 0
for row in rows {
 let input = row[0] as! String, expected = row[1] as! [String]
 let candidates = engine.candidates(for: input)
 var shown = Array(candidates.prefix(4)); if !shown.contains(input) { shown.append(input) }
 if expected.contains(where: candidates.contains) { hits += 1 }
 if expected.contains(where: shown.contains) { visible += 1 }
 if let first = candidates.first, expected.contains(first) { top += 1 }
}
print("holdout total \(rows.count), expected among all candidates \(hits), visible on candidate row \(visible), first choice \(top)")
