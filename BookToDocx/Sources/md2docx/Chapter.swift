import Foundation

enum ContentBlock {
    case title([InlineRun])     // from "# " lines — the chapter's own heading
    case subhead([InlineRun])   // from "## " lines — mid-chapter subheadings
    case paragraph([InlineRun])
    case sceneBreak             // from a lone "***" or "✦" line

    var isTitle: Bool {
        if case .title = self { return true }
        return false
    }

    var isSubhead: Bool {
        if case .subhead = self { return true }
        return false
    }
}

struct ChapterFile {
    /// Everything the file says, in file order — headings included. Nothing
    /// is ever added from outside (file name, contents file), and nothing
    /// in the file is dropped.
    let blocks: [ContentBlock]

    /// The chapter's opening `# ` heading as plain text, for places that need
    /// a bare string (an XHTML `<title>`, say) rather than styled runs.
    var openingHeading: String? {
        for block in blocks {
            if case .title(let runs) = block { return runs.plainText }
        }
        return nil
    }

    /// Parses one chapter markdown file. Layout rules:
    ///  - The first non-blank line must be an H1 (`# Title`) — it becomes the
    ///    chapter's printed heading.
    ///  - Blank lines separate blocks.
    ///  - A line that is exactly `***` or `✦` is a scene break.
    ///  - A line starting with `## ` is a mid-chapter subheading.
    ///  - Any other run of consecutive non-blank lines is one paragraph
    ///    (soft-wrapped source lines are joined with a single space).
    static func parse(fileURL: URL) throws -> ChapterFile {
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        var lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        while let first = lines.first, first.isEmpty {
            lines.removeFirst()
        }
        guard let titleLine = lines.first, titleLine.hasPrefix("# ") else {
            throw BuildError("\(fileURL.lastPathComponent): expected the file to start with '# Title'")
        }

        var blocks: [ContentBlock] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(.paragraph(InlineMarkdown.parse(paragraphLines.joined(separator: " "))))
            paragraphLines.removeAll()
        }

        for line in lines {
            if line.isEmpty {
                flushParagraph()
                continue
            }
            if line == "***" || line == "✦" {
                flushParagraph()
                blocks.append(.sceneBreak)
                continue
            }
            if line.hasPrefix("## ") {
                flushParagraph()
                let text = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                blocks.append(.subhead(InlineMarkdown.parse(text)))
                continue
            }
            if line.hasPrefix("# ") {
                flushParagraph()
                let text = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                blocks.append(.title(InlineMarkdown.parse(text)))
                continue
            }
            paragraphLines.append(line)
        }
        flushParagraph()

        return ChapterFile(blocks: blocks)
    }
}
