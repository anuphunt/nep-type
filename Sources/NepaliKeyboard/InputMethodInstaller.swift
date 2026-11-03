import Foundation

enum InputMethodInstaller {
    enum Failure: LocalizedError {
        case invalidBundle, alreadyInstalled
        var errorDescription: String? {
            switch self {
            case .invalidBundle: return "The bundled NepType keyboard is missing or its signature could not be verified. Reinstall the complete NepType app."
            case .alreadyInstalled: return "A NepType keyboard is already installed. Select it in Keyboard Settings. To replace it, first switch to another input source, remove the old NepType Input app from your Library/Input Methods folder, then install again."
            }
        }
    }

    /// Copies only our signed bundle, without enabling or selecting an input source.
    static func install(source: URL, directory: URL) throws -> URL {
        let fm = FileManager.default
        guard let bundle = Bundle(url: source),
              bundle.bundleIdentifier == "local.anup.inputmethod.NepType",
              let executable = bundle.executableURL, fm.isExecutableFile(atPath: executable.path)
        else { throw Failure.invalidBundle }
        let staging = fm.temporaryDirectory.appendingPathComponent("neptype-install-" + UUID().uuidString + ".app")
        defer { try? fm.removeItem(at: staging) }
        try fm.copyItem(at: source, to: staging)
        // Finder may decorate an app after signing. Remove only that decoration
        // on our private copy; preserve quarantine and other security metadata.
        for attribute in ["com.apple.FinderInfo", "com.apple.ResourceFork"] {
            let cleanup = Process()
            cleanup.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            cleanup.arguments = ["-dr", attribute, staging.path]
            cleanup.standardError = FileHandle.nullDevice
            try cleanup.run(); cleanup.waitUntilExit()
        }
        let check = Process()
        check.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        check.arguments = ["--verify", "--deep", "--strict", staging.path]
        check.standardOutput = FileHandle.nullDevice
        check.standardError = FileHandle.nullDevice
        try check.run(); check.waitUntilExit()
        guard check.terminationStatus == 0 else { throw Failure.invalidBundle }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("NepType Input.app", isDirectory: true)
        guard !fm.fileExists(atPath: destination.path) else { throw Failure.alreadyInstalled }
        try fm.moveItem(at: staging, to: destination)
        return destination
    }
}
