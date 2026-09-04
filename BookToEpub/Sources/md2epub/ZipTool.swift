import Foundation

/// Thin wrapper around the system `zip` binary (present on every Mac). An
/// .epub is a zip archive with one hard requirement beyond a plain archive:
/// the `mimetype` entry must be the very first entry, stored (uncompressed).
/// Shelling out avoids pulling in a third-party archiving dependency for
/// what is otherwise a pure-Foundation tool.
enum ZipTool {

    /// Zips `sourceDir` (which must already contain `mimetype`, `META-INF/`
    /// and `OEBPS/`) into a valid `.epub` at `archive`.
    static func createEpub(from sourceDir: URL, archive: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: archive.path) {
            try fm.removeItem(at: archive)
        }
        // mimetype first, stored (no compression, level 0).
        try run("/usr/bin/zip", ["-X0q", archive.path, "mimetype"], currentDirectory: sourceDir)
        // Everything else, deflated, appended to the archive just created.
        try run("/usr/bin/zip", ["-rX9q", archive.path, "META-INF", "OEBPS"], currentDirectory: sourceDir)
    }

    private static func run(_ launchPath: String, _ arguments: [String], currentDirectory: URL? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        if let currentDirectory = currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8) ?? ""
            throw BuildError("\(launchPath) \(arguments.joined(separator: " ")) failed: \(errText)")
        }
    }
}
