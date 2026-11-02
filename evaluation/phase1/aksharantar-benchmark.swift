import Foundation
let e = Transliterator()
let start = DispatchTime.now().uptimeNanoseconds
precondition(e.aksharantarCandidates(for:"bhaisakeko").contains("भइसकेको"))
let loaded = DispatchTime.now().uptimeNanoseconds
let words=["bhaisakeko", "pratikriya", "laptop", "nayanirwachit", "abhinandana", "namaste", "zzzzzz", "ramro"]
var samples=[Double]()
for i in 0..<100_000 {
 let t=DispatchTime.now().uptimeNanoseconds
 _=e.candidates(for: words[i % words.count])
 samples.append(Double(DispatchTime.now().uptimeNanoseconds-t)/1_000)
}
samples.sort()
print(String(format:"First Aksharantar lookup: %.3f ms",Double(loaded-start)/1_000_000))
print(String(format:"Complete candidate lookup (100000): p50 %.3f µs p95 %.3f µs p99 %.3f µs",samples[50000],samples[95000],samples[99000]))
