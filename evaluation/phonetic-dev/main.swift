import Foundation
struct Case: Decodable { let roman: String; let expected: [String]; let role: String }
struct Corpus: Decodable { let cases: [Case] }
let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let engine = Transliterator()
func alternateKeys(_ word: String) -> [String] {
    let chars = Array(word)
    var output: [String] = []
    for i in chars.indices {
        let vowel = chars[i]
        guard vowel == "a" || vowel == "i" || vowel == "u" else { continue }
        if i > 0 && chars[i - 1] == vowel { continue }
        var changed = chars
        if i + 1 < chars.count && chars[i + 1] == vowel { changed.remove(at: i + 1) }
        else { changed.insert(vowel, at: i + 1) }
        let value = String(changed)
        if !output.contains(value) { output.append(value) }
        if output.count == 4 { break }
    }
    return output
}
func augmented(_ word: String, base: [String]) -> [String] {
    guard word == word.lowercased(), (3...20).contains(word.count), word.utf8.allSatisfy({ (97...122).contains($0) }), !engine.isKnownEnglish(word), GeneratedAliasIndex.aksharantarLookup(word).count < 2 else { return base }
    var extra: [String] = []
    var seen = Set(base)
    for alternate in alternateKeys(word) {
        for candidate in (GeneratedAliasIndex.aksharantarLookup(alternate) + GeneratedAliasIndex.lookup(alternate)) where seen.insert(candidate).inserted {
            extra.append(candidate)
            if extra.count == 2 { break }
        }
        if extra.count == 2 { break }
    }
    // Existing priorities stay first and original is never lost.
    if let last = base.last, last == word { return Array(base.dropLast()) + extra + [word] }
    return base + extra
}
func visible(_ values: [String], original: String) -> [String] {
    var v = Array(values.prefix(4)); if !v.contains(original) { v.append(original) }; return v
}
var details: [[String: Any]] = []
var counts: [String:[String:Int]] = [:]
for c in corpus.cases {
    guard let choice = engine.contextChoices(in: c.roman).first else { fatalError(c.roman) }
    let before = engine.contextualCandidates(for: choice)
    let english = engine.isKnownEnglish(c.roman)
    let exactCount = GeneratedAliasIndex.aksharantarLookup(c.roman.lowercased()).count
    let after = augmented(c.roman, base: before)
    let beforeVisible = visible(before, original:c.roman), afterVisible = visible(after, original:c.roman)
    let canon = Set(c.expected.map { $0.precomposedStringWithCanonicalMapping })
    let b = beforeVisible.contains { canon.contains($0.precomposedStringWithCanonicalMapping) }
    let a = afterVisible.contains { canon.contains($0.precomposedStringWithCanonicalMapping) }
    let extras = after.filter { !before.contains($0) }
    counts[c.role, default:[:]]["total",default:0] += 1
    if b { counts[c.role, default:[:]]["visible_before",default:0] += 1 }
    if a { counts[c.role, default:[:]]["visible_after",default:0] += 1 }
    counts[c.role, default:[:]]["added_candidates",default:0] += extras.count
    counts[c.role, default:[:]]["added_matching_reference",default:0] += extras.filter { canon.contains($0.precomposedStringWithCanonicalMapping) }.count
    details.append(["roman":c.roman,"role":c.role,"knownEnglish":english,"exactCount":exactCount,"reference":c.expected,"before":beforeVisible,"after":afterVisible,"added":extras,"top_unchanged":before.first == after.first])
}
let payload:[String:Any] = ["counts":counts,"details":details,"note":"unreviewed hand-authored development fixture; added-reference match is not linguistic precision"]
let out=try JSONSerialization.data(withJSONObject:payload,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]); FileHandle.standardOutput.write(out); FileHandle.standardOutput.write(Data("\n".utf8))
if CommandLine.arguments.contains("--bench") {
    let test = corpus.cases.map(\.roman)
    func bench(_ expanded: Bool) -> (Double,Double) {
        var samples:[Double] = []
        for i in 0..<1200 {
            let word=test[i % test.count]
            let start=DispatchTime.now().uptimeNanoseconds
            if let choice=engine.contextChoices(in:word).first {
                let base=engine.contextualCandidates(for:choice)
                if expanded { _ = augmented(word,base:base) }
            }
            samples.append(Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000)
        }
        samples.sort(); return (samples[600],samples[1140])
    }
    _ = bench(false)
    let b=bench(false), a=bench(true)
    fputs(String(format:"warm local p50/p95 ms baseline %.4f/%.4f expanded %.4f/%.4f, n=1200 each\n",b.0,b.1,a.0,a.1),stderr)
}
