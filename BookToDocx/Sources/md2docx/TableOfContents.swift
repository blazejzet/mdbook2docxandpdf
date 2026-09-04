import Foundation

/// One row of the contents file's markdown table.
struct TOCEntry {
    let nr: Int
    let title: String
    let code: String
}

struct Act {
    let name: String
    var entries: [TOCEntry]
}

/// The parsed contents file (`00 - Content.md`). Every piece of text it
/// contributes to the book — the heading of the contents page itself, the
/// act names, the chapter titles listed there — is read from the file, so
/// nothing about it is language-specific in code.
struct BookContents {
    /// The `## ` line: what this book calls its contents page ("Spis
    /// treści", "Table of Contents", ...). Never derived from the file name.
    let heading: String
    let acts: [Act]
}

enum TableOfContents {
    /// Parses the contents file:
    ///  - `## Heading` — the contents page's own title (required, once).
    ///  - `### Act name` — opens a new act; must precede the first table row.
    ///  - `| Nr | Title | Code |` rows — register chapters in the open act.
    ///
    /// A leading `# ` line (the book title) is ignored here: `00 - Bookinfo.md`
    /// is the single source of truth for the book's own metadata.
    static func parse(fileURL: URL) throws -> BookContents {
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        let name = fileURL.lastPathComponent
        var heading: String?
        var acts: [Act] = []

        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("### ") {
                let actName = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                acts.append(Act(name: actName, entries: []))
                continue
            }

            if line.hasPrefix("## ") {
                guard heading == nil else {
                    throw BuildError("\(name): more than one '## ' line — the contents page has exactly one heading")
                }
                heading = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                continue
            }

            guard line.hasPrefix("|") else { continue }
            let cells = line
                .split(separator: "|", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 3 else { continue }
            guard let nr = Int(cells[0]) else { continue } // skips header/separator rows

            guard !acts.isEmpty else {
                throw BuildError("\(name): row for chapter #\(nr) appears before any '### Act' heading")
            }
            acts[acts.count - 1].entries.append(
                TOCEntry(nr: nr, title: cells[1], code: cells[2])
            )
        }

        guard let heading = heading, !heading.isEmpty else {
            throw BuildError("\(name): must contain a '## ' line naming the contents page in the book's own language, e.g. '## Table of Contents'")
        }
        guard !acts.isEmpty else {
            throw BuildError("\(name): no '### Act' sections found")
        }
        return BookContents(heading: heading, acts: acts)
    }
}
