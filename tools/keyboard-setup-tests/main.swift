import Foundation

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent("neptype-installer-test-" + UUID().uuidString)
try fm.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: root) }
let destination = try InputMethodInstaller.install(source: source, directory: root.appendingPathComponent("Input Methods"))
assert(Bundle(url: destination)?.bundleIdentifier == "local.anup.inputmethod.NepType")
let marker = destination.appendingPathComponent("existing-install-marker")
try Data("preserve".utf8).write(to: marker)
do {
    _ = try InputMethodInstaller.install(source: source, directory: destination.deletingLastPathComponent())
    fatalError("Must not replace an existing installation")
} catch InputMethodInstaller.Failure.alreadyInstalled { }
let preserved = try String(contentsOf: marker, encoding: .utf8)
assert(preserved == "preserve")
do {
    _ = try InputMethodInstaller.install(source: root.appendingPathComponent("missing.app"), directory: root.appendingPathComponent("Invalid"))
    fatalError("Must reject a missing bundle")
} catch InputMethodInstaller.Failure.invalidBundle { }
assert(!fm.fileExists(atPath: root.appendingPathComponent("Invalid").path))
print("Installer passed: signed bundle copied, existing installation preserved, missing bundle rejected. No system input sources changed.")
