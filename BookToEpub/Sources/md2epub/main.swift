import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("error: \(message)\n".data(using: .utf8)!)
    exit(1)
}

struct CLIOptions {
    var bookDir = URL(fileURLWithPath: "book")
    var tocFileName: String?
    var bookInfoFileName: String?
    var lang: String?
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
                  --toc <file>        Override the contents file name (default: whichever of
                                      "00 - Content.md" / "00_SPIS_TRESCI.md" the book has)
                  --bookinfo <file>   Override the metadata file name (default: whichever of
                                      "00 - Bookinfo.md" / "00_BOOKINFO.md" the book has)
                  --lang <code>       EPUB language code, e.g. pl, en. Overrides the
                                      LANGUAGE: field in bookinfo.md; without either,
                                      defaults to pl and warns.
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

    let source = try BookSource.detect(
        bookDir: opts.bookDir,
        bookInfoOverride: opts.bookInfoFileName,
        contentsOverride: opts.tocFileName
    )
    print("Layout: \(source.schema.description) (\(source.bookInfoURL.lastPathComponent) + \(source.contentsURL.lastPathComponent))")

    print("Reading \(source.bookInfoURL.lastPathComponent)...")
    let bookInfo = try BookInfo.parse(fileURL: source.bookInfoURL)

    // The book's own LANGUAGE: field is the source of truth; --lang overrides
    // it for one-off builds. A silent default would quietly ship an English
    // book declaring Polish, which readers and shops both act on.
    let lang: String
    if let flag = opts.lang {
        lang = flag
    } else if let declared = bookInfo.language {
        lang = declared
    } else {
        lang = "pl"
        print("warning: no LANGUAGE: field in \(source.bookInfoURL.lastPathComponent) and no --lang given; declaring '\(lang)'.")
    }
    print("Language: \(lang)")

    print("Reading \(source.contentsURL.lastPathComponent)...")
    let contents = try TableOfContents.parse(source: source)
    let acts = contents.acts
    for skipped in contents.skippedSections {
        print("note: section '\(skipped)' lists no chapters and is left out of the book.")
    }

    // CONTENTS: in bookinfo wins; the numbered-table schema can also declare
    // the heading as the contents file's own '## ' line.
    let contentsHeading = bookInfo.contentsHeading ?? contents.heading
    if contentsHeading == nil {
        print("warning: no CONTENTS: field in \(source.bookInfoURL.lastPathComponent); the contents page gets no heading.")
    }
    let chapterCount = acts.reduce(0) { $0 + $1.entries.count }
    print("Found \(acts.count) acts, \(chapterCount) chapters.")

    print("Parsing chapter files...")
    var chapters: [Int: ChapterFile] = [:]
    for act in acts {
        for entry in act.entries {
            chapters[entry.nr] = try ChapterFile.parse(fileURL: entry.fileURL)
        }
    }

    let cover = try CoverImage.resolve(explicitPath: opts.coverPath, bookDir: opts.bookDir)
    if let cover = cover {
        print("Using cover image \(cover.sourceURL.path)")
    } else {
        print("No cover image found (looked for \(opts.bookDir.appendingPathComponent("cover.jpg").path)); building without one.")
    }

    print("Building EPUB parts...")
    let files = try EpubBuilder.build(bookInfo: bookInfo, contents: contents, heading: contentsHeading, chapters: chapters, lang: lang, cover: cover)

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

    let outputURL = opts.output ?? URL(fileURLWithPath: "\(bookInfo.fileNameSafeTitle).epub")
    print("Zipping \(outputURL.lastPathComponent)...")
    try ZipTool.createEpub(from: workDir, archive: outputURL)

    print("Done: \(outputURL.path)")
} catch {
    fail("\(error)")
}
