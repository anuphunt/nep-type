import Foundation
let data = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
var count = 0
for line in data.split(separator: "\n") {
 let parts = line.split(separator:"\t").map(String.init)
 guard GeneratedAliasIndex.lookup(parts[0]) == Array(parts.dropFirst()) else { fatalError("Mismatch: \(parts[0])") }
 count += 1
}
precondition(GeneratedAliasIndex.lookup("zzzzzzzzzzzzzzzzzz").isEmpty)
print("Verified \(count) exact index keys and their full candidate lists")
