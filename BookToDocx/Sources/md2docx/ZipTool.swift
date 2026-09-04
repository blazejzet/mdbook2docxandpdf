import Foundation

/// Thin wrapper around the system `zip`/`unzip` binaries (present on every
/// Mac). A .docx is just a zip archive, so shelling out avoids pulling in a
/// third-party archiving dependency for what is otherwise a pure-Foundation
/// tool.
enum ZipTool {

    static func extract(archive: URL, to destinationDir: URL) throws {
        try run("/usr/bin/unzip", ["-oq", archive.path, "-d", destinationDir.path])
    }

    /// Zips the *contents* of `sourceDir` (not the directory itself) into
    /// `archive`, preserving the relative paths — exactly what a .docx needs.
    static func create(from sourceDir: URL, archive: URL) throws {
        if FileManager.default.fileExists(atPath: archive.path) {
            try FileManager.default.removeItem(at: archive)
        }
        try run("/usr/bin/zip", ["-rq", "-X", archive.path, "."], currentDirectory: sourceDir)
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
