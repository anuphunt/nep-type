import UIKit
import Darwin

func memory() -> (UInt64, UInt64) {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let status: kern_return_t = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return status == KERN_SUCCESS ? (info.resident_size, info.phys_footprint) : (0, 0)
}
@main final class App: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds);window.rootViewController = UIViewController();window.makeKeyAndVisible();self.window = window
        DispatchQueue.main.async { self.run() }; return true
    }
    func run() {
        let mode = CommandLine.arguments.dropFirst().first ?? "raw"
        let root = Bundle.main.resourceURL!
        let tsv = root.appendingPathComponent("aksharantar-indiccorp-v1.tsv").path
        let lki = root.appendingPathComponent("aksharantar-indiccorp-v1.lki").path
        setenv("LEKHA_AKSHARANTAR_INDEX", tsv, 1)
        let before = memory(), start = DispatchTime.now().uptimeNanoseconds
        let packed = mode == "packed" ? PackedIndex(path:lki) : nil
        let initialization = Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000
        let keys = ["namaste","mero","pani","football","bhaisakeko","bhetau","ghar","janchu","namuna","ramro"]
        var times:[Double]=[], total=0
        for i in 0..<2000 {
            let t=DispatchTime.now().uptimeNanoseconds
            let values = mode == "packed" ? packed!.lookup(keys[i % keys.count]) : GeneratedAliasIndex.aksharantarLookup(keys[i % keys.count])
            total += values.count; times.append(Double(DispatchTime.now().uptimeNanoseconds-t)/1_000_000)
        }
        let first=times.removeFirst();times.sort();let after=memory()
        let output:[String:Any]=["mode":mode,"init_ms":initialization,"init_plus_first_ms":initialization+first,"first_ms":first,"total_ms":Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000,"p50_ms":times[times.count/2],"p95_ms":times[Int(Double(times.count)*0.95)],"resident_before":before.0,"resident_after":after.0,"footprint_before":before.1,"footprint_after":after.1,"candidate_count":total]
        let data=try! JSONSerialization.data(withJSONObject:output,options:.sortedKeys)
        try! data.write(to:FileManager.default.temporaryDirectory.appendingPathComponent("packed-bench.json"))
        print(String(data:data,encoding:.utf8)!);fflush(stdout);exit(0)
    }
}
