import Foundation

/// Which layout a book's two front-matter files use. Both carry the same
/// information; they differ only in how the contents file lists chapters.
enum ContentsSchema {
    /// `00 - Bookinfo.md` + `00 - Content.md`: a `## ` contents heading,
    /// `### ` acts, and a `| Nr | Title | Code |` table whose Nr column is
    /// matched against the leading number of each chapter file's name.
    case numberedTable

    /// `00_BOOKINFO.md` + `00_SPIS_TRESCI.md` (or `00_CONTENTS.md`):
    /// `## ` parts, each holding markdown list items that link straight to
    /// the chapter file — `- [Chapter 1. Title](R01_title.md) — 4029 words.`
    case linkedList

    var description: String {
        switch self {
        case .numberedTable: return "numbered table"
        case .linkedList: return "linked list"
        }
    }
}

/// One known on-disk layout: the pair of file names that identifies it.
private struct Layout {
    let schema: ContentsSchema
    let bookInfoName: String
    let contentsNames: [String]   // first match wins
}

/// The front-matter files of one book directory, and the schema they follow.
///
/// The schema is recognised by which of the known starting files are present,
/// never by their content — a directory either has `00 - Content.md` or it has
/// `00_SPIS_TRESCI.md`, and that is what says how to read it.
struct BookSource {
    let schema: ContentsSchema
    let bookInfoURL: URL
    let contentsURL: URL
    let bookDir: URL

    private static let layouts = [
        Layout(schema: .numberedTable,
               bookInfoName: "00 - Bookinfo.md",
               contentsNames: ["00 - Content.md"]),
        Layout(schema: .linkedList,
               bookInfoName: "00_BOOKINFO.md",
               contentsNames: ["00_SPIS_TRESCI.md", "00_CONTENTS.md"]),
    ]

    /// Probes `bookDir` for each known layout. `bookInfoOverride` and
    /// `contentsOverride` (the --bookinfo / --toc flags) replace the file
    /// names of whichever layout was recognised; they do not change how the
    /// contents file is read.
    static func detect(bookDir: URL, bookInfoOverride: String?, contentsOverride: String?) throws -> BookSource {
        let fm = FileManager.default
        func exists(_ name: String) -> URL? {
            let url = bookDir.appendingPathComponent(name)
            return fm.fileExists(atPath: url.path) ? url : nil
        }

        for layout in layouts {
            guard let bookInfoURL = exists(layout.bookInfoName) else { continue }
            guard let contentsURL = layout.contentsNames.compactMap({ exists($0) }).first else { continue }
            return BookSource(
                schema: layout.schema,
                bookInfoURL: bookInfoOverride.map { bookDir.appendingPathComponent($0) } ?? bookInfoURL,
                contentsURL: contentsOverride.map { bookDir.appendingPathComponent($0) } ?? contentsURL,
                bookDir: bookDir
            )
        }

        // Nothing matched: if the flags name both files outright, honour them
        // under the schema whose contents file the given name looks like.
        if let bookInfoOverride = bookInfoOverride, let contentsOverride = contentsOverride {
            let schema: ContentsSchema = layouts[1].contentsNames.contains(contentsOverride) ? .linkedList : .numberedTable
            return BookSource(
                schema: schema,
                bookInfoURL: bookDir.appendingPathComponent(bookInfoOverride),
                contentsURL: bookDir.appendingPathComponent(contentsOverride),
                bookDir: bookDir
            )
        }

        let expected = layouts
            .map { "  \($0.schema.description): \($0.bookInfoName) + \($0.contentsNames.joined(separator: " or "))" }
            .joined(separator: "\n")
        throw BuildError("""
        \(bookDir.path): no recognised book layout. Expected one of:
        \(expected)
        """)
    }
}
