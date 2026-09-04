import Foundation

/// Downscales a cover image for on-screen reading. Source cover files often
/// come straight from a print-cover export (a 300dpi paperback wrap
/// flattened to an image) — far larger, in pixel dimensions and file size,
/// than any e-reader needs, and epub stores commonly reject or complain
/// about oversized covers. This only ever shrinks; a cover already smaller
/// than `maxDimension` is copied through untouched, and vector (.svg)
/// covers are never touched since there's nothing to downscale.
enum CoverProcessor {
    /// Longest edge, in pixels, a raster cover is downscaled to fit within.
    /// 2400px comfortably covers what any current e-reader/store wants
    /// (Kindle/Apple Books/Kobo all top out well under that) while keeping
    /// file size reasonable.
    static let defaultMaxDimension = 2400

    struct Result {
        let downscaledFrom: (width: Int, height: Int)?
    }

    @discardableResult
    static func prepare(cover: CoverImage, destination: URL, maxDimension: Int) throws -> Result {
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        guard cover.mediaType != "image/svg+xml" else {
            try fm.copyItem(at: cover.sourceURL, to: destination)
            return Result(downscaledFrom: nil)
        }

        guard let size = pixelSize(of: cover.sourceURL) else {
            // Couldn't read dimensions (unexpected file contents, sips
            // missing, ...) — fall back to copying the original rather than
            // failing the whole build over a cosmetic optimization.
            try fm.copyItem(at: cover.sourceURL, to: destination)
            return Result(downscaledFrom: nil)
        }

        guard max(size.width, size.height) > maxDimension else {
            try fm.copyItem(at: cover.sourceURL, to: destination)
            return Result(downscaledFrom: nil)
        }

        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try run("/usr/bin/sips", ["-Z", String(maxDimension), cover.sourceURL.path, "--out", destination.path])
        return Result(downscaledFrom: size)
    }

    private static func pixelSize(of url: URL) -> (width: Int, height: Int)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = ["-g", "pixelWidth", "-g", "pixelHeight", url.path]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let output = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var width: Int?
        var height: Int?
        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let value = intValue(line, afterPrefix: "pixelWidth:") {
                width = value
            } else if let value = intValue(line, afterPrefix: "pixelHeight:") {
                height = value
            }
        }
        guard let w = width, let h = height else { return nil }
        return (w, h)
    }

    private static func intValue(_ line: String, afterPrefix prefix: String) -> Int? {
        guard line.hasPrefix(prefix) else { return nil }
        return Int(line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces))
    }

    private static func run(_ launchPath: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
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
