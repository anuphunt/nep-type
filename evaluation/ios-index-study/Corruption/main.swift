import Foundation
let args = CommandLine.arguments
let index = PackedIndex(path: args[1])
if args[2] == "invalid" { guard index == nil else { fatalError("accepted invalid header") } }
else { guard let index, index.lookup(args[3]).isEmpty else { fatalError("accepted malformed row/block") } }
print("PASS: \(args[2])")
