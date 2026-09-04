import Foundation

enum StyleID {
    static let bookTitle = "Endure-BookTitle"
    static let bookSubtitle = "Endure-BookSubtitle"
    static let authorName = "Endure-AuthorName"
    static let copyrightPage = "Endure-CopyrightPage"
    static let chapterTitle = "Endure-ChapterTitle"
    static let frontMatterBody = "Endure-FrontMatterBodyText"
    static let firstParagraph = "Endure-FirstParagraphBodyText"
    static let chapterBody = "Endure-ChapterBodyText"
    static let subhead = "Endure-Subhead"
}

/// One Word section: fully-formed paragraph strings (no sectPr embedded yet)
/// plus the sectPr that closes it out. `finalize()` decides, per section,
/// whether that sectPr gets folded into the last paragraph (every section
/// but the last) or appended at body level (the final section only).
private struct DocSection {
    var paragraphs: [String] = []
    let sectPrXML: String
}

struct BuiltBook {
    let bodyXML: String
}

enum DocumentBuilder {

    static func build(bookInfo: BookInfo, acts: [Act], chapters: [Int: ChapterFile]) throws -> BuiltBook {
        var sections: [DocSection] = []
        var bookmarkID = 1
        func nextBookmarkID() -> Int {
            defer { bookmarkID += 1 }
            return bookmarkID
        }

        // MARK: Title page
        do {
            var paras: [String] = []
            paras.append(OOXML.paragraph(style: StyleID.bookTitle, runsXML: OOXML.run(bookInfo.title)))
            if let subtitle = bookInfo.subtitle {
                paras.append(OOXML.paragraph(style: StyleID.bookSubtitle, runsXML: OOXML.run(subtitle)))
            }
            paras.append(OOXML.paragraph(style: StyleID.authorName, runsXML: OOXML.run(bookInfo.author)))
            sections.append(DocSection(
                paragraphs: paras,
                sectPrXML: Section.sectPr(pageNumbers: .lowerRoman(start: 1), hideFirstPageNumber: true, vAlign: "center")
            ))
        }

        // MARK: Copyright page
        do {
            var paras: [String] = []
            paras.append(OOXML.paragraph(style: StyleID.copyrightPage, runsXML: OOXML.run(bookInfo.title)))
            paras.append(OOXML.paragraph(style: StyleID.copyrightPage, runsXML: OOXML.run(bookInfo.author)))
            paras.append(OOXML.emptyParagraph(style: StyleID.copyrightPage))
            paras.append(OOXML.paragraph(style: StyleID.copyrightPage, runsXML: OOXML.run("Copyright © \(bookInfo.copyrightYear) \(bookInfo.author)")))
            paras.append(OOXML.paragraph(style: StyleID.copyrightPage, runsXML: OOXML.run("All rights reserved.")))
            paras.append(OOXML.emptyParagraph(style: StyleID.copyrightPage))
            if let isbn = bookInfo.isbn {
                paras.append(OOXML.paragraph(style: StyleID.copyrightPage, runsXML: OOXML.run("ISBN: \(isbn)")))
            }
            if let printingDate = bookInfo.printingDate {
                paras.append(OOXML.paragraph(style: StyleID.copyrightPage, runsXML: OOXML.run("First printing: \(printingDate)")))
            }
            sections.append(DocSection(
                paragraphs: paras,
                sectPrXML: Section.sectPr(pageNumbers: .lowerRomanContinued, hideFirstPageNumber: true, vAlign: "bottom")
            ))
        }

        // MARK: Table of contents
        do {
            var paras: [String] = []
            paras.append(OOXML.paragraph(style: StyleID.chapterTitle, jc: "center", runsXML: OOXML.run("Spis treści")))
            paras.append(OOXML.emptyParagraph(style: StyleID.frontMatterBody))

            for (actIndex, act) in acts.enumerated() {
                let actBookmark = "act\(actIndex + 1)"
                // NB: this line only *references* the act's bookmark via PAGEREF;
                // the bookmark itself is declared once, at the act divider page below.
                let actRuns = OOXML.run(act.name)
                    + OOXML.tabRun()
                    + OOXML.pageRefFieldRuns(bookmark: actBookmark)
                paras.append(OOXML.paragraph(
                    style: StyleID.subhead,
                    jc: nil,
                    extraPPr: OOXML.tocTab(pos: PageGeometry.textWidth - 100),
                    runsXML: actRuns
                ))

                for entry in act.entries {
                    let runs = OOXML.run(entry.title)
                        + OOXML.tabRun()
                        + OOXML.pageRefFieldRuns(bookmark: "ch\(entry.nr)")
                    paras.append(OOXML.paragraph(
                        style: nil,
                        extraPPr: OOXML.tocTab(pos: PageGeometry.textWidth - 100),
                        runsXML: runs
                    ))
                }
                paras.append(OOXML.emptyParagraph(style: nil))
            }

            sections.append(DocSection(
                paragraphs: paras,
                sectPrXML: Section.sectPr(pageNumbers: .lowerRomanContinued, hideFirstPageNumber: false)
            ))
        }

        // MARK: Acts and chapters
        for (actIndex, act) in acts.enumerated() {
            let actBookmark = "act\(actIndex + 1)"
            let actID = nextBookmarkID()
            let actTitleRuns = OOXML.bookmarkStart(id: actID, name: actBookmark)
                + OOXML.run(act.name)
                + OOXML.bookmarkEnd(id: actID)
            sections.append(DocSection(
                paragraphs: [OOXML.paragraph(style: StyleID.chapterTitle, runsXML: actTitleRuns)],
                sectPrXML: Section.sectPr(
                    pageNumbers: actIndex == 0 ? .decimal(start: 1) : .decimalContinued,
                    hideFirstPageNumber: false,
                    vAlign: "center"
                )
            ))

            for entry in act.entries {
                guard let chapter = chapters[entry.nr] else {
                    throw BuildError("No chapter file found for TOC entry #\(entry.nr) (\(entry.title))")
                }
                sections.append(chapterSection(entry: entry, chapter: chapter))
            }
        }

        // MARK: Assemble body XML
        var body = ""
        for (index, section) in sections.enumerated() {
            if index == sections.count - 1 {
                body += section.paragraphs.joined()
                body += section.sectPrXML
            } else {
                var paras = section.paragraphs
                guard let last = paras.popLast() else { continue }
                body += paras.joined()
                body += injectSectPr(into: last, sectPr: section.sectPrXML)
            }
        }

        return BuiltBook(bodyXML: body)
    }

    /// Builds one chapter's section: the drop-spaced heading, then its body
    /// blocks. The section's closing sectPr is always returned embeddable;
    /// the top-level assembly loop is what decides whether it ends up
    /// folded into the last paragraph or appended at body level (only the
    /// very last section of the whole document gets the latter).
    private static func chapterSection(entry: TOCEntry, chapter: ChapterFile) -> DocSection {
        var paras: [String] = []
        let headingBookmarkID = chapterHeadingBookmarkID(for: entry.nr)

        for _ in 0..<5 {
            paras.append(OOXML.emptyParagraph(style: StyleID.chapterTitle))
        }
        paras.append(OOXML.paragraph(
            style: StyleID.chapterTitle,
            runsXML: OOXML.bookmarkStart(id: headingBookmarkID, name: "ch\(entry.nr)")
                + OOXML.run(entry.headingMain)
                + OOXML.bookmarkEnd(id: headingBookmarkID)
        ))
        if let sub = entry.headingSub {
            paras.append(OOXML.paragraph(style: StyleID.subhead, jc: "center", runsXML: OOXML.run(sub)))
        } else {
            paras.append(OOXML.emptyParagraph(style: StyleID.chapterTitle))
        }

        var nextIsFirst = true
        for block in chapter.blocks {
            switch block {
            case .paragraph(let runs):
                let style = nextIsFirst ? StyleID.firstParagraph : StyleID.chapterBody
                paras.append(OOXML.paragraph(style: style, runsXML: OOXML.runs(runs)))
                nextIsFirst = false
            case .subhead(let runs):
                paras.append(OOXML.paragraph(style: StyleID.subhead, jc: "center", runsXML: OOXML.runs(runs)))
                nextIsFirst = true
            case .sceneBreak:
                // "3x newline; centered ✦; 3x newline" — two blank lines on
                // each side of the glyph, matching the empty-paragraph
                // spacing idiom used for the chapter-title drop above.
                for _ in 0..<2 {
                    paras.append(OOXML.emptyParagraph(style: StyleID.frontMatterBody))
                }
                paras.append(OOXML.paragraph(style: StyleID.frontMatterBody, jc: "center", runsXML: OOXML.run("✦")))
                for _ in 0..<2 {
                    paras.append(OOXML.emptyParagraph(style: StyleID.frontMatterBody))
                }
                nextIsFirst = true
            }
        }

        let sectPr = Section.sectPr(pageNumbers: .decimalContinued, hideFirstPageNumber: false)
        return DocSection(paragraphs: paras, sectPrXML: sectPr)
    }

    /// Bookmark IDs must be unique document-wide; chapter headings are built
    /// once per chapter so a local counter would collide across chapters.
    /// We instead give each chapter heading bookmark a globally-unique id
    /// derived from its (unique) TOC number, offset well clear of the
    /// front-matter/act counters allocated in `build(...)`.
    private static func chapterHeadingBookmarkID(for nr: Int) -> Int {
        1000 + nr
    }

    private static func injectSectPr(into lastParagraph: String, sectPr: String) -> String {
        guard let range = lastParagraph.range(of: "</w:pPr>") else {
            // No pPr present (a bare, unstyled empty paragraph) — synthesize one.
            let insertionPoint = lastParagraph.index(lastParagraph.startIndex, offsetBy: "<w:p>".count)
            var copy = lastParagraph
            copy.insert(contentsOf: "<w:pPr>\(sectPr)</w:pPr>", at: insertionPoint)
            return copy
        }
        var copy = lastParagraph
        copy.insert(contentsOf: sectPr, at: range.lowerBound)
        return copy
    }
}
