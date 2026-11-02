import Foundation
let e = Transliterator()
let start = DispatchTime.now().uptimeNanoseconds
let first = e.experimentalCandidates(for: "bato")
let loaded = DispatchTime.now().uptimeNanoseconds
precondition(first.contains("बाटो"))
let queries = ["bato", "biralo", "zzzzzz", "pani", "sundar", "karyalaya", "bihana", "pokhara"]
var samples = [Double]()
for i in 0..<100_000 {
    let t = DispatchTime.now().uptimeNanoseconds
    _ = e.candidates(for: queries[i % queries.count])
    samples.append(Double(DispatchTime.now().uptimeNanoseconds - t) / 1_000)
}
samples.sort()
print(String(format:"Alias index cold first lookup: %.3f ms",Double(loaded-start)/1_000_000))
print(String(format:"Full candidate lookup (100000), µs: p50 %.3f p95 %.3f p99 %.3f",samples[50000],samples[95000],samples[99000]))
