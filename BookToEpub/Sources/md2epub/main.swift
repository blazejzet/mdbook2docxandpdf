import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("error: \(message)\n".data(using: .utf8)!)
    exit(1)
}

struct CLIOptions {
    var bookDir = URL(fileURLWithPath: "book")
    var tocFileName = "00 - Content.md"
    var bookInfoFileName = "00 - Bookinfo.md"
    var lang = "pl"
    var coverPath: URL?
    var coverMaxDimension = CoverProcessor.defaultMaxDimension
    var output: URL?

    static func parse(_ args: [String]) -> CLIOptions {
        var opts = CLIOptions()
        var i = 0
        while i < args.count {
            let arg = args[i]
            func value() -> String {
                i += 1
                guard i < args.count else { fail("missing value for \(arg)") }
                return args[i]
            }
            switch arg {
            case "--book": opts.bookDir = URL(fileURLWithPath: value())
            case "--toc": opts.tocFileName = value()
            case "--bookinfo": opts.bookInfoFileName = value()
            case "--lang": opts.lang = value()
            case "--cover": opts.coverPath = URL(fileURLWithPath: value())
            case "--cover-max-dimension":
                let raw = value()
                guard let n = Int(raw), n > 0 else { fail("--cover-max-dimension expects a positive integer, got '\(raw)'") }
                opts.coverMaxDimension = n
            case "--output", "-o": opts.output = URL(fileURLWithPath: value())
            case "--help", "-h":
                print("""
                Usage: md2epub [options]

                Converts a folder of chapter markdown files into a single, valid
                EPUB3 ebook: title page, copyright page, navigable table of
                contents, act dividers, chapters. Reads the same book/ source
                layout as md2docx.

                Options:
                  --book <dir>        Directory with chapter .md files (default: book)
                  --toc <file>        Contents markdown filename inside --book (default: 00 - Content.md)
                  --bookinfo <file>   Book metadata markdown filename inside --book (default: 00 - Bookinfo.md)
                  --lang <code>       EPUB language code, e.g. pl, en (default: pl)
                  --cover <file>      Cover image (.jpg/.jpeg/.png/.gif/.svg). Downscaled to fit
                                      --cover-max-dimension if larger (source is often a print-
                                      resolution export); never upscaled. Default: <book>/cover.jpg,
                                      silently omitted if that file doesn't exist.
                  --cover-max-dimension <px>
                                      Longest edge, in pixels, a raster cover is downscaled to
                                      (default: \(CoverProcessor.defaultMaxDimension))
                  --output, -o <file> Output .epub path (default: "<Title>.epub" from bookinfo.md)
                """)
                exit(0)
            default:
                fail("unknown option \(arg)")
            }
            i += 1
        }
        return opts
    }
}

let opts = CLIOptions.parse(Array(CommandLine.arguments.dropFirst()))

do {
    let fm = FileManager.default

    guard fm.fileExists(atPath: opts.bookDir.path) else {
        fail("book directory not found: \(opts.bookDir.path)")
    }

    let bookInfoURL = opts.bookDir.appendingPathComponent(opts.bookInfoFileName)
    let tocURL = opts.bookDir.appendingPathComponent(opts.tocFileName)

    print("Reading \(opts.bookInfoFileName)...")
    let bookInfo = try BookInfo.parse(fileURL: bookInfoURL)

    print("Reading \(opts.tocFileName)...")
    let contents = try TableOfContents.parse(fileURL: tocURL)
    let acts = contents.acts
    let chapterCount = acts.reduce(0) { $0 + $1.entries.count }
    print("Found \(acts.count) acts, \(chapterCount) chapters.")

    // Map each TOC row's chapter number to its markdown file, matched by the
    // file's leading "NN - " prefix.
    let allFiles = try fm.contentsOfDirectory(at: opts.bookDir, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension.lowercased() == "md" }
    var fileByNumber: [Int: URL] = [:]
    for file in allFiles {
        let name = file.deletingPathExtension().lastPathComponent
        guard let dashRange = name.range(of: " - ") else { continue }
        guard let nr = Int(name[name.startIndex..<dashRange.lowerBound]) else { continue }
        fileByNumber[nr] = file
    }

    print("Parsing chapter files...")
    var chapters: [Int: ChapterFile] = [:]
    for act in acts {
        for entry in act.entries {
            guard let fileURL = fileByNumber[entry.nr] else {
                fail("no markdown file found for chapter #\(entry.nr) (\(entry.title)) — expected a file named '\(String(format: "%02d", entry.nr)) - ...md' in \(opts.bookDir.path)")
            }
            chapters[entry.nr] = try ChapterFile.parse(fileURL: fileURL)
        }
    }

    let cover = try CoverImage.resolve(explicitPath: opts.coverPath, bookDir: opts.bookDir)
    if let cover = cover {
        print("Using cover image \(cover.sourceURL.path)")
    } else {
        print("No cover image found (looked for \(opts.bookDir.appendingPathComponent("cover.jpg").path)); building without one.")
    }

    print("Building EPUB parts...")
    let files = try EpubBuilder.build(bookInfo: bookInfo, contents: contents, chapters: chapters, lang: opts.lang, cover: cover)

    let workDir = fm.temporaryDirectory.appendingPathComponent("md2epub-\(UUID().uuidString)")
    try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: workDir) }

    print("Writing package files...")
    for (relativePath, content) in files {
        let fileURL = workDir.appendingPathComponent(relativePath)
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    if let cover = cover {
        let destURL = workDir.appendingPathComponent("OEBPS").appendingPathComponent(cover.href)
        let result = try CoverProcessor.prepare(cover: cover, destination: destURL, maxDimension: opts.coverMaxDimension)
        if let from = result.downscaledFrom {
            print("Cover downscaled from \(from.width)x\(from.height) to fit \(opts.coverMaxDimension)px (looked like a print-resolution source).")
        }
    }

    let outputURL = opts.output ?? URL(fileURLWithPath: "\(bookInfo.title).epub")
    print("Zipping \(outputURL.lastPathComponent)...")
    try ZipTool.createEpub(from: workDir, archive: outputURL)

    print("Done: \(outputURL.path)")
} catch {
    fail("\(error)")
}
