import Foundation
struct Sample: Decodable { let split: String; let input: String; let expected: String }
let samples = try JSONDecoder().decode([Sample].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let engine = Transliterator()
let rows = samples.map { sample -> [String:String] in ["split":sample.split,"input":sample.input,"expected":sample.expected,"actual":engine.render(sample.input)] }
let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
FileHandle.standardOutput.write(data)
