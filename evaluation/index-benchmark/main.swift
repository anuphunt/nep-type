import Foundation
struct Work: Decodable { let cases: [Item] }
struct Item: Decodable { let key: String; let category: String; let expected: [String] }
let work = try JSONDecoder().decode(Work.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let iterations = Int(CommandLine.arguments[2])!
var times:[String:[UInt64]] = [:]
var errors:[String] = []
var counts:[String:Int] = [:]
for pass in 0..<iterations {
 for item in work.cases {
  let start=DispatchTime.now().uptimeNanoseconds
  let actual=GeneratedAliasIndex.aksharantarLookup(item.key)
  let elapsed=DispatchTime.now().uptimeNanoseconds-start
  times[item.category,default:[]].append(elapsed)
  counts[item.category,default:0] += 1
  if actual != item.expected && errors.count < 20 { errors.append("\(pass):\(item.key)") }
 }
}
func stats(_ v:[UInt64])->[String:Double] {let a=v.sorted();func q(_ p:Double)->Double { Double(a[min(a.count-1,Int(ceil(Double(a.count)*p))-1)])/1_000_000 };return ["median_ms":q(0.5),"p95_ms":q(0.95),"p99_ms":q(0.99),"max_ms":Double(a.last!)/1_000_000,"n":Double(a.count)]}
let result:[String:Any] = ["stats":times.mapValues(stats),"counts":counts,"mismatch_examples":errors]
let data=try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]);FileHandle.standardOutput.write(data);FileHandle.standardOutput.write(Data("\n".utf8))
if !errors.isEmpty { exit(1) }
