import Foundation

/// Metadata parsed from bookinfo.md. Expected format is simple `KEY: value` lines,
/// one per field, blank lines allowed between them, optionally followed by a
/// `---` line and the copyright page's own text.
struct BookInfo {
    var title: String
    var subtitle: String?
    var author: String
    var isbn: String?
    var printingDate: String?
    /// `LANGUAGE:` — a BCP 47 code ("en", "pl", "de"). Belongs in the book's
    /// own metadata rather than in a command-line flag that is easy to drop
    /// on a rebuild: a book's language is a property of the book.
    var language: String?
    /// `CONTENTS:` — what this book calls its table of contents ("Spis
    /// treści", "Table of Contents"). The numbered-table schema can also
    /// carry it as the `## ` line of the contents file; the linked-list
    /// schema has no room for it there, so it belongs here.
    var contentsHeading: String?
    /// The copyright / imprint page, written out by the author below a `---`
    /// line in the metadata file: one entry per source line, an empty entry
    /// being a blank spacer line. It is reproduced verbatim (inline
    /// `**bold**` / `*italic*` still apply), so its wording and language are
    /// the book's own — nothing here is generated or translated in code.
    var copyrightPage: [String]

    static func parse(fileURL: URL) throws -> BookInfo {
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        let allLines = raw.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // A `---` line, if present, separates the `KEY: value` metadata above
        // from the free-text copyright page below.
        let separator = allLines.firstIndex(where: { $0 == "---" })
        let fieldLines = separator.map { Array(allLines[..<$0]) } ?? allLines
        var pageLines = separator.map { Array(allLines[(($0) + 1)...]) } ?? []
        while let first = pageLines.first, first.isEmpty { pageLines.removeFirst() }
        while let last = pageLines.last, last.isEmpty { pageLines.removeLast() }

        var fields: [String: String] = [:]
        for line in fieldLines {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colonIndex]
                .trimmingCharacters(in: .whitespaces)
                .uppercased()
            let value = line[line.index(after: colonIndex)...]
                .trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }
            fields[key] = value
        }

        guard let title = fields["TITLE"] else {
            throw BuildError("\(fileURL.lastPathComponent) must define a TITLE: field")
        }
        guard let author = fields["AUTHOR"] else {
            throw BuildError("\(fileURL.lastPathComponent) must define an AUTHOR: field")
        }

        return BookInfo(
            title: title,
            subtitle: fields["SUBTITLE"],
            author: author,
            isbn: fields["ISBN"],
            printingDate: fields["PRINTING DATE"] ?? fields["PRINTING_DATE"],
            language: fields["LANGUAGE"],
            contentsHeading: fields["CONTENTS"],
            copyrightPage: pageLines
        )
    }

    /// The title reduced to something safe to use as a file name. Colons and
    /// path separators are the ones that matter: macOS still treats ":" as a
    /// legacy separator, and upload pipelines that key off the file name
    /// (KDP's among them) mangle or misidentify files carrying them.
    /// "A: B" becomes "A - B"; a title with none of these is untouched.
    var fileNameSafeTitle: String {
        let illegal = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let parts = title
            .components(separatedBy: illegal)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? title : parts.joined(separator: " - ")
    }

    /// Best-effort 4-digit year extracted from the printing date, for the copyright notice.
    var copyrightYear: String {
        if let printingDate = printingDate,
           let match = printingDate.range(of: #"\d{4}"#, options: .regularExpression) {
            return String(printingDate[match])
        }
        return String(Calendar.current.component(.year, from: Date()))
    }

    /// The copyright page to lay out: the author's own text when the metadata
    /// file carries one, otherwise a minimal language-neutral fallback
    /// (title, author, "© year author", ISBN) that invents no wording.
    func copyrightPageLines(isbn printedISBN: String?) -> [String] {
        if !copyrightPage.isEmpty { return copyrightPage }
        var lines = [title, author, "", "© \(copyrightYear) \(author)"]
        if let printedISBN = printedISBN {
            lines += ["", "ISBN \(printedISBN)"]
        }
        return lines
    }
}

struct BuildError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
