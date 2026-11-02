import Foundation
let e = Transliterator()
let start = DispatchTime.now().uptimeNanoseconds
precondition(e.isKnownEnglish("architecture"))
let initialized = DispatchTime.now().uptimeNanoseconds
let words = ["mountains", "unrecognizedwordxyz", "elephant", "photosynthesis", "airport", "Coffee", "document", "happiness"]
var durations: [Double] = []
var hits = 0
for i in 0..<100_000 {
    let begin = DispatchTime.now().uptimeNanoseconds
    if e.isKnownEnglish(words[i % words.count]) { hits += 1 }
    durations.append(Double(DispatchTime.now().uptimeNanoseconds - begin) / 1_000.0)
}
durations.sort()
print(String(format: "Cold first membership including lazy index initialization: %.3f ms", Double(initialized-start)/1_000_000.0))
print(String(format: "English exact lookup (100000 calls), microseconds: p50 %.3f, p95 %.3f, p99 %.3f; hits %d",durations[50000],durations[95000],durations[99000],hits))
let t=DispatchTime.now().uptimeNanoseconds
for _ in 0..<100_000 { _ = e.candidates(for: "pani") }
print(String(format: "Nepali candidate lookup mean (100000 calls): %.3f µs",Double(DispatchTime.now().uptimeNanoseconds-t)/100_000.0/1000.0))
