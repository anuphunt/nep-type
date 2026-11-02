import Foundation
let args = CommandLine.arguments
let sample = try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
guard let packed = PackedIndex(path: args[2]) else { fatalError("invalid packed file") }
let isMined = args[3] == "mined"
let start = DispatchTime.now().uptimeNanoseconds
var mismatches = 0
for key in sample {
    let expected = isMined ? GeneratedAliasIndex.aksharantarLookup(key) : GeneratedAliasIndex.lookup(key)
    let got = packed.lookup(key)
    if expected != got { mismatches += 1; if mismatches < 10 { print("MISMATCH \(key): \(expected) vs \(got)") } }
}
let ms = Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000
print("\(mismatches == 0 ? "PASS" : "FAIL"): \(sample.count) lookups; \(mismatches) mismatches; combined comparison \(ms) ms")
exit(mismatches == 0 ? 0 : 1)
