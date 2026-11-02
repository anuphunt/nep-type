import Foundation
let args = CommandLine.arguments
let packedMode = args[1] == "packed"
let keys = ["namaste", "mero", "pani", "football", "bhaisakeko", "bhetau", "ghar", "janchu", "namuna", "ramro"]
let start = DispatchTime.now().uptimeNanoseconds
let packed: PackedIndex? = packedMode ? PackedIndex(path: args[2]) : nil
let initMs = Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000
var durations: [Double] = [], total = 0
for i in 0..<2000 {
 let t = DispatchTime.now().uptimeNanoseconds
 let values = packedMode ? packed!.lookup(keys[i % keys.count]) : GeneratedAliasIndex.aksharantarLookup(keys[i % keys.count])
 durations.append(Double(DispatchTime.now().uptimeNanoseconds-t)/1_000_000);total += values.count
}
let first = durations[0]; durations.removeFirst();durations.sort()
let output: [String:Any] = ["mode":args[1],"init_ms":initMs,"init_plus_first_ms":initMs + first,"first_ms":first,"warm_p50_ms":durations[durations.count/2],"warm_p95_ms":durations[Int(Double(durations.count)*0.95)],"total_ms":Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000,"candidate_count":total]
print(String(data:try JSONSerialization.data(withJSONObject:output,options:.sortedKeys),encoding:.utf8)!)
