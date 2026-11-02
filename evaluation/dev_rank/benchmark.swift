import Foundation
let e = Transliterator()
let keys = ["farkinchu", "aaunchan", "bolchu", "padhchu", "bhanincha", "sakincha", "garchan", "hinchu", "architecture", "office", "pani", "football"]
for key in keys { _ = e.candidates(for: key) }
var times: [Double] = []
for _ in 0..<100 {
    for key in keys {
        let start = DispatchTime.now().uptimeNanoseconds
        _ = e.candidates(for: key)
        times.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
    }
}
times.sort()
print(String(format: "samples=%d median_ms=%.4f p95_ms=%.4f p99_ms=%.4f max_ms=%.4f", times.count, times[times.count/2], times[Int(Double(times.count-1)*0.95)], times[Int(Double(times.count-1)*0.99)], times.last!))
