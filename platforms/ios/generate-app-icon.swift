// Compatibility entry point: swift platforms/ios/generate-app-icon.swift
// Export from the approved artwork; never redraw a placeholder over the logo.
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["python3", root.appendingPathComponent("scripts/export-brand-assets.py").path]
try process.run()
process.waitUntilExit()
exit(process.terminationStatus)
