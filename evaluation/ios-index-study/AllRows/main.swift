import Foundation
let args = CommandLine.arguments
guard let packed = PackedIndex(path: args[1]) else { fatalError("invalid packed") }
let mined = args[2] == "mined"
var count = 0
let start = DispatchTime.now().uptimeNanoseconds
while let key = readLine() {
 let expected = mined ? GeneratedAliasIndex.aksharantarLookup(key) : GeneratedAliasIndex.lookup(key)
 let actual = packed.lookup(key)
 if expected != actual { fputs("FAIL at \(count) key \(key)\n", stderr); exit(1) }
 count += 1
 if count % 500000 == 0 { fputs("validated \(count)\n",stderr) }
}
print("PASS: \(count) key lookups exactly equal; elapsed_ms=\(Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000)")
