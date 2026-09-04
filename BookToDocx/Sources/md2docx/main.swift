import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("error: \(message)\n".data(using: .utf8)!)
    exit(1)
}

/// Where the install script (see install.sh) drops its bundled templates,
/// and the fallback location `--template` is resolved against when it isn't
/// found as given — the common case once md2docx is installed to
/// ~/.bookapps/bin and invoked from an arbitrary book project directory that
/// has no local templates/ folder of its own.
let appTemplatesDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".bookapps", isDirectory: true)
    .appendingPathComponent("templates", isDirectory: true)
    .appendingPathComponent("docx", isDirectory: true)

/// Resolves a `--template` value: first as given (absolute, or relative to
/// the current directory), then by basename inside `appTemplatesDir`.
func resolveTemplate(_ path: URL) -> URL? {
    let fm = FileManager.default
    if fm.fileExists(atPath: path.path) {
        return path
    }
    let fallback = appTemplatesDir.appendingPathComponent(path.lastPathComponent)
    if fm.fileExists(atPath: fallback.path) {
        return fallback
    }
    return nil
}

struct CLIOptions {
    var bookDir = URL(fileURLWithPath: "book")
    var templatePath = URL(fileURLWithPath: "5.5 x 8.5 in.docx")
    var tocFileName = "00 - Spis treści.md"
    var bookInfoFileName = "00 - Bookinfo.md"
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
            case "--template": opts.templatePath = URL(fileURLWithPath: value())
            case "--toc": opts.tocFileName = value()
            case "--bookinfo": opts.bookInfoFileName = value()
            case "--output", "-o": opts.output = URL(fileURLWithPath: value())
            case "--help", "-h":
                print("""
                Usage: md2docx [options]

                Converts a folder of chapter markdown files into a .docx that follows
                the layout of a 5x8 book template (title page, copyright page, table
                of contents with live page numbers, act dividers, chapters).

                Options:
                  --book <dir>        Directory with chapter .md files (default: book)
                  --template <file>   Template .docx to copy styling from (default: 5.5 x 8.5 in.docx).
                                      Resolved as given (relative to the current directory, or
                                      absolute); if not found there, falls back to a file of the
                                      same name under \(appTemplatesDir.path).
                  --toc <file>        TOC markdown filename inside --book (default: 00 - Spis treści.md)
                  --bookinfo <file>   Book metadata markdown filename inside --book (default: 00 - Bookinfo.md)
                  --output, -o <file> Output .docx path (default: "<Title>.docx" from bookinfo.md)
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
    guard let templatePath = resolveTemplate(opts.templatePath) else {
        let fallback = appTemplatesDir.appendingPathComponent(opts.templatePath.lastPathComponent)
        fail("template not found: tried \(opts.templatePath.path) and \(fallback.path)")
    }

    let bookInfoURL = opts.bookDir.appendingPathComponent(opts.bookInfoFileName)
    let tocURL = opts.bookDir.appendingPathComponent(opts.tocFileName)

    print("Reading \(opts.bookInfoFileName)...")
    let bookInfo = try BookInfo.parse(fileURL: bookInfoURL)

    print("Reading \(opts.tocFileName)...")
    let acts = try TableOfContents.parse(fileURL: tocURL)
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

    print("Building document.xml...")
    let built = try DocumentBuilder.build(bookInfo: bookInfo, acts: acts, chapters: chapters)

    let workDir = fm.temporaryDirectory.appendingPathComponent("md2docx-\(UUID().uuidString)")
    try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: workDir) }

    print("Reading template styling from \(templatePath.path)...")
    let assets = try TemplateAssets.load(templateDocx: templatePath, workDir: workDir)

    let stagingDir = workDir.appendingPathComponent("staging")
    let wordDir = stagingDir.appendingPathComponent("word")
    let themeDir = wordDir.appendingPathComponent("theme")
    let docPropsDir = stagingDir.appendingPathComponent("docProps")
    let relsDir = stagingDir.appendingPathComponent("_rels")
    let wordRelsDir = wordDir.appendingPathComponent("_rels")
    for dir in [stagingDir, wordDir, themeDir, docPropsDir, relsDir, wordRelsDir] {
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func write(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    print("Assembling .docx parts...")
    try write(PartsBuilder.documentXML(bodyXML: built.bodyXML), to: wordDir.appendingPathComponent("document.xml"))
    try write(assets.stylesXML, to: wordDir.appendingPathComponent("styles.xml"))
    try write(PartsBuilder.patchSettings(assets.settingsXML), to: wordDir.appendingPathComponent("settings.xml"))
    try write(assets.webSettingsXML, to: wordDir.appendingPathComponent("webSettings.xml"))
    try write(assets.fontTableXML, to: wordDir.appendingPathComponent("fontTable.xml"))
    try write(assets.footnotesXML, to: wordDir.appendingPathComponent("footnotes.xml"))
    try write(assets.endnotesXML, to: wordDir.appendingPathComponent("endnotes.xml"))
    try write(assets.themeXML, to: themeDir.appendingPathComponent("theme1.xml"))

    // header1/footer1 = blank; header2 = default (book title); header3 = even (author); footer2 = page number.
    try write(PartsBuilder.blankHeader(), to: wordDir.appendingPathComponent("header1.xml"))
    try write(PartsBuilder.header(text: bookInfo.title), to: wordDir.appendingPathComponent("header2.xml"))
    try write(PartsBuilder.header(text: bookInfo.author), to: wordDir.appendingPathComponent("header3.xml"))
    try write(PartsBuilder.blankFooter(), to: wordDir.appendingPathComponent("footer1.xml"))
    try write(PartsBuilder.pageNumberFooter(), to: wordDir.appendingPathComponent("footer2.xml"))

    try write(PartsBuilder.coreProperties(bookInfo: bookInfo), to: docPropsDir.appendingPathComponent("core.xml"))
    try write(PartsBuilder.appProperties(), to: docPropsDir.appendingPathComponent("app.xml"))
    try write(PartsBuilder.customProperties(bookInfo: bookInfo), to: docPropsDir.appendingPathComponent("custom.xml"))

    try write(PartsBuilder.contentTypesXML(), to: stagingDir.appendingPathComponent("[Content_Types].xml"))
    try write(PartsBuilder.documentRels(), to: wordRelsDir.appendingPathComponent("document.xml.rels"))
    try write(PartsBuilder.packageRels(), to: relsDir.appendingPathComponent(".rels"))

    let outputURL = opts.output ?? URL(fileURLWithPath: "\(bookInfo.title).docx")
    print("Zipping \(outputURL.lastPathComponent)...")
    try ZipTool.create(from: stagingDir, archive: outputURL)

    print("Done: \(outputURL.path)")
} catch {
    fail("\(error)")
}
