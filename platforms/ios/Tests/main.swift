import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
let start = DispatchTime.now().uptimeNanoseconds
var session = InputSession()
require(session.append("namaste"), "accept roman")
require(session.candidates.contains("नमस्ते"), "Nepali candidate")
require(session.candidates.contains("namaste"), "original candidate")
require(session.select("नमस्ते"), "select candidate")
require(session.commit() == "नमस्ते", "commit selected candidate")
require(session.append("mero"), "accept another word")
require(session.cancel() == "mero", "preserve original on cancel")
session.toggleLanguage()
require(!session.append("hello"), "English is passthrough")
let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
print(String(format: "PASS: core snapshot composition/candidate/original; cold first sequence %.2f ms (macOS process, not iOS)", ms))
