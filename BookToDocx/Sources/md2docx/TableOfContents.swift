import Foundation

/// One chapter as the contents file lists it.
struct TOCEntry {
    /// 1-based position in the finished book, assigned while parsing. Only
    /// used to build stable internal ids (bookmarks, file names); it is not
    /// the "Nr" column, which merely locates a file in the numbered-table
    /// schema.
    let nr: Int
    /// The chapter's label *in the table of contents*. The heading printed on
    /// the chapter's own page comes from the chapter file, not from here.
    let title: String
    /// Free-form column of the numbered-table schema; never interpreted.
    let code: String?
    let fileURL: URL
}

struct Act {
    let name: String
    var entries: [TOCEntry]
}

/// The parsed contents file.
struct BookContents {
    /// The contents page's own title, in the book's language. Optional: the
    /// numbered-table schema carries it as a `## ` line, the linked-list
    /// schema has no place for it and takes it from `CONTENTS:` in bookinfo.
    let heading: String?
    let acts: [Act]
    /// `## ` sections that held no chapters (manuscript notes and the like)
    /// and were left out of the book. Reported so that a section dropped
    /// because of a typo doesn't vanish silently.
    let skippedSections: [String]
}

enum TableOfContents {

    static func parse(source: BookSource) throws -> BookContents {
        let raw = try String(contentsOf: source.contentsURL, encoding: .utf8)
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let name = source.contentsURL.lastPathComponent

        switch source.schema {
        case .numberedTable:
            return try parseNumberedTable(lines: lines, name: name, bookDir: source.bookDir)
        case .linkedList:
            return try parseLinkedList(lines: lines, name: name, bookDir: source.bookDir)
        }
    }

    // MARK: - Numbered table

    /// `## Heading`, `### Act`, then `| Nr | Title | Code |` rows whose Nr is
    /// matched against the leading number of a chapter file's name.
    private static func parseNumberedTable(lines: [String], name: String, bookDir: URL) throws -> BookContents {
        let filesByNumber = try chapterFilesByLeadingNumber(in: bookDir)
        var heading: String?
        var acts: [Act] = []
        var nextNr = 1

        for line in lines {
            if line.hasPrefix("### ") {
                acts.append(Act(name: String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces), entries: []))
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
            guard cells.count >= 3, let number = Int(cells[0]) else { continue } // skips header/separator rows
            guard !acts.isEmpty else {
                throw BuildError("\(name): row for chapter #\(number) appears before any '### Act' heading")
            }
            guard let fileURL = filesByNumber[number] else {
                throw BuildError("\(name): no markdown file for chapter #\(number) (\(cells[1])) — expected a file named '\(String(format: "%02d", number)) - ....md' in \(bookDir.path)")
            }
            acts[acts.count - 1].entries.append(
                TOCEntry(nr: nextNr, title: cells[1], code: cells[2], fileURL: fileURL)
            )
            nextNr += 1
        }

        guard !acts.isEmpty else {
            throw BuildError("\(name): no '### Act' sections found")
        }
        return BookContents(heading: heading, acts: acts, skippedSections: [])
    }

    /// Maps the leading "NN" of each top-level `NN - ....md` file name to its URL.
    private static func chapterFilesByLeadingNumber(in bookDir: URL) throws -> [Int: URL] {
        let files = try FileManager.default
            .contentsOfDirectory(at: bookDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "md" }
        var byNumber: [Int: URL] = [:]
        for file in files {
            let stem = file.deletingPathExtension().lastPathComponent
            guard let dash = stem.range(of: " - "),
                  let number = Int(stem[stem.startIndex..<dash.lowerBound]) else { continue }
            byNumber[number] = file
        }
        return byNumber
    }

    // MARK: - Linked list

    /// `## Part`, then markdown list items linking straight to a chapter file:
    /// `- [Chapter 1. Title](R01_title.md) — 4029 words.`
    ///
    /// Only list items count. A bare link in a paragraph (editorial notes, a
    /// link to a companion document) is not a chapter, and a `## ` section
    /// holding no list items is not a part of the book — which is what keeps
    /// a manuscript-status section out of the finished text.
    private static func parseLinkedList(lines: [String], name: String, bookDir: URL) throws -> BookContents {
        let fm = FileManager.default
        var sections: [Act] = []
        var skipped: [String] = []
        var nextNr = 1

        for line in lines {
            if line.hasPrefix("### ") { continue }
            if line.hasPrefix("## ") {
                sections.append(Act(name: String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces), entries: []))
                continue
            }
            guard let item = listItemLink(line) else { continue }
            guard item.target.lowercased().hasSuffix(".md") else { continue }
            guard !sections.isEmpty else {
                throw BuildError("\(name): chapter '\(item.label)' appears before any '## ' part heading")
            }
            let fileURL = bookDir.appendingPathComponent(item.target)
            guard fm.fileExists(atPath: fileURL.path) else {
                throw BuildError("\(name): '\(item.label)' links to \(item.target), which does not exist in \(bookDir.path)")
            }
            sections[sections.count - 1].entries.append(
                TOCEntry(nr: nextNr, title: item.label, code: nil, fileURL: fileURL)
            )
            nextNr += 1
        }

        var acts: [Act] = []
        for section in sections {
            if section.entries.isEmpty {
                skipped.append(section.name)
            } else {
                acts.append(section)
            }
        }

        guard !acts.isEmpty else {
            throw BuildError("\(name): no chapters found — expected '## Part' headings holding '- [Title](file.md)' list items")
        }
        return BookContents(heading: nil, acts: acts, skippedSections: skipped)
    }

    /// Reads `- [label](target)` (also `*` / `+` bullets). Anything after the
    /// closing paren — a word count, a note — is deliberately ignored: it is
    /// manuscript bookkeeping, not part of the book.
    private static func listItemLink(_ line: String) -> (label: String, target: String)? {
        guard let bullet = line.first, "-*+".contains(bullet) else { return nil }
        let afterBullet = line.dropFirst()
        guard let firstChar = afterBullet.first, firstChar == " " || firstChar == "\t" else { return nil }
        let rest = afterBullet.trimmingCharacters(in: .whitespaces)

        guard rest.hasPrefix("["), let labelEnd = rest.firstIndex(of: "]") else { return nil }
        let afterLabel = rest.index(after: labelEnd)
        guard afterLabel < rest.endIndex, rest[afterLabel] == "(" else { return nil }
        let targetStart = rest.index(after: afterLabel)
        guard let targetEnd = rest[targetStart...].firstIndex(of: ")") else { return nil }

        let label = String(rest[rest.index(after: rest.startIndex)..<labelEnd]).trimmingCharacters(in: .whitespaces)
        let rawTarget = String(rest[targetStart..<targetEnd]).trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty, !rawTarget.isEmpty else { return nil }
        return (label, rawTarget.removingPercentEncoding ?? rawTarget)
    }
}
