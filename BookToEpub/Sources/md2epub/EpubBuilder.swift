import Foundation

private struct ManifestItem {
    let id: String
    let href: String       // relative to OEBPS/
    let mediaType: String
    var properties: String?
}

private struct ChapterRef {
    let entry: TOCEntry
    let id: String
    let href: String       // relative to OEBPS/
}

private struct ActGroup {
    let act: Act
    let actID: String
    let actHref: String     // relative to OEBPS/
    let chapters: [ChapterRef]
}

enum EpubBuilder {

    /// Builds every *text* file an EPUB3 package needs, keyed by its path
    /// relative to the archive root (e.g. "mimetype", "OEBPS/content.opf",
    /// "OEBPS/text/ch-001.xhtml"). The caller writes each entry to disk,
    /// separately copies the cover image's actual bytes to `cover.href`
    /// (this map is text-only), and zips the result.
    ///
    /// Every word a reader sees comes from the book's markdown: chapter
    /// headings from the chapter files, act names and the contents page's
    /// heading from `00 - Content.md`, the copyright page and title from
    /// `00 - Bookinfo.md`. Labels this builder has to emit for structural
    /// navigation reuse those same strings rather than English defaults.
    static func build(bookInfo: BookInfo, contents: BookContents, chapters: [Int: ChapterFile], lang: String, cover: CoverImage?) throws -> [String: String] {
        let identifier = Identifier.forBook(bookInfo)

        var files: [String: String] = [:]
        var manifest: [ManifestItem] = []
        var spineIDs: [String] = []

        files["mimetype"] = "application/epub+zip"

        files["META-INF/container.xml"] = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """

        files["OEBPS/css/stylesheet.css"] = stylesheet
        manifest.append(ManifestItem(id: "css", href: "css/stylesheet.css", mediaType: "text/css"))

        if let cover = cover {
            manifest.append(ManifestItem(id: "cover-image", href: cover.href, mediaType: cover.mediaType, properties: "cover-image"))
            files["OEBPS/text/cover.xhtml"] = coverXHTML(cover: cover, bookInfo: bookInfo, lang: lang)
            manifest.append(ManifestItem(id: "cover", href: "text/cover.xhtml", mediaType: "application/xhtml+xml"))
            spineIDs.append("cover")
        }

        files["OEBPS/text/titlepage.xhtml"] = titlePageXHTML(bookInfo: bookInfo, lang: lang)
        manifest.append(ManifestItem(id: "titlepage", href: "text/titlepage.xhtml", mediaType: "application/xhtml+xml"))
        spineIDs.append("titlepage")

        files["OEBPS/text/copyright.xhtml"] = copyrightXHTML(bookInfo: bookInfo, lang: lang)
        manifest.append(ManifestItem(id: "copyright", href: "text/copyright.xhtml", mediaType: "application/xhtml+xml"))
        spineIDs.append("copyright")

        // Reserved now, written after the act/chapter hrefs below are known.
        manifest.append(ManifestItem(id: "nav", href: "nav.xhtml", mediaType: "application/xhtml+xml", properties: "nav"))
        spineIDs.append("nav")

        var actGroups: [ActGroup] = []
        for (actIndex, act) in contents.acts.enumerated() {
            let actID = "act\(actIndex + 1)"
            let actHref = "text/act-\(actIndex + 1).xhtml"
            files["OEBPS/\(actHref)"] = actDividerXHTML(act: act, lang: lang)
            manifest.append(ManifestItem(id: actID, href: actHref, mediaType: "application/xhtml+xml"))
            spineIDs.append(actID)

            var refs: [ChapterRef] = []
            for entry in act.entries {
                guard let chapter = chapters[entry.nr] else {
                    throw BuildError("No chapter file found for TOC entry #\(entry.nr) (\(entry.title))")
                }
                let padded = String(format: "%03d", entry.nr)
                let chID = "ch\(padded)"
                let chHref = "text/ch-\(padded).xhtml"
                files["OEBPS/\(chHref)"] = chapterXHTML(entry: entry, chapter: chapter, lang: lang)
                manifest.append(ManifestItem(id: chID, href: chHref, mediaType: "application/xhtml+xml"))
                spineIDs.append(chID)
                refs.append(ChapterRef(entry: entry, id: chID, href: chHref))
            }
            actGroups.append(ActGroup(act: act, actID: actID, actHref: actHref, chapters: refs))
        }

        files["OEBPS/nav.xhtml"] = navXHTML(bookInfo: bookInfo, heading: contents.heading, acts: actGroups, lang: lang, cover: cover)

        manifest.append(ManifestItem(id: "ncx", href: "toc.ncx", mediaType: "application/x-dtbncx+xml"))
        files["OEBPS/toc.ncx"] = tocNCX(bookInfo: bookInfo, heading: contents.heading, acts: actGroups, lang: lang, identifier: identifier)

        files["OEBPS/content.opf"] = contentOPF(
            bookInfo: bookInfo,
            lang: lang,
            identifier: identifier,
            manifest: manifest,
            spineIDs: spineIDs,
            heading: contents.heading,
            firstAct: actGroups.first,
            cover: cover
        )

        return files
    }

    // MARK: - Pages

    private static func page(title: String, lang: String, cssHref: String = "../css/stylesheet.css", bodyXML: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="\(lang)" xml:lang="\(lang)">
        <head>
        <meta charset="utf-8"/>
        <title>\(XHTML.escape(title))</title>
        <link rel="stylesheet" type="text/css" href="\(cssHref)"/>
        </head>
        <body>
        \(bodyXML)
        </body>
        </html>
        """
    }

    /// The image is never resized to a fixed size — `img { max-width;
    /// max-height }` in the stylesheet scales it to whatever screen or page
    /// displays it, so any source resolution or aspect ratio works.
    private static func coverXHTML(cover: CoverImage, bookInfo: BookInfo, lang: String) -> String {
        let body = """
        <section class="cover" epub:type="cover">
        <img src="../\(cover.href)" alt="\(XHTML.escape(bookInfo.title))"/>
        </section>
        """
        return page(title: bookInfo.title, lang: lang, bodyXML: body)
    }

    private static func titlePageXHTML(bookInfo: BookInfo, lang: String) -> String {
        var body = "<section class=\"titlepage\" epub:type=\"titlepage\">\n"
        body += "<h1>\(XHTML.escape(bookInfo.title))</h1>\n"
        if let subtitle = bookInfo.subtitle {
            body += "<p class=\"subtitle\">\(XHTML.escape(subtitle))</p>\n"
        }
        body += "<p class=\"author\">\(XHTML.escape(bookInfo.author))</p>\n"
        body += "</section>"
        return page(title: bookInfo.title, lang: lang, bodyXML: body)
    }

    /// The copyright page is whatever `00 - Bookinfo.md` says it is — one
    /// paragraph per source line, blank lines kept as spacers — so its
    /// wording is the author's, in the book's language.
    private static func copyrightXHTML(bookInfo: BookInfo, lang: String) -> String {
        var body = "<section class=\"copyright\" epub:type=\"copyright-page\">\n"
        for line in bookInfo.copyrightPageLines(isbn: bookInfo.isbnDigits) {
            if line.isEmpty {
                body += "<p class=\"spacer\">&#160;</p>\n"
            } else {
                body += "<p>\(XHTML.render(InlineMarkdown.parse(line)))</p>\n"
            }
        }
        body += "</section>"
        return page(title: bookInfo.title, lang: lang, bodyXML: body)
    }

    private static func actDividerXHTML(act: Act, lang: String) -> String {
        let body = "<section class=\"act-divider\" epub:type=\"part\">\n<h1>\(XHTML.escape(act.name))</h1>\n</section>"
        return page(title: act.name, lang: lang, bodyXML: body)
    }

    /// One chapter's page: exactly the blocks its markdown file contains, in
    /// file order. The heading printed here is the file's own `# ` line —
    /// never the file name, and never the title from the contents file
    /// (which labels the chapter in the TOC only).
    private static func chapterXHTML(entry: TOCEntry, chapter: ChapterFile, lang: String) -> String {
        var body = "<section class=\"chapter\" epub:type=\"chapter\" id=\"ch\(entry.nr)\">\n"
        var nextIsOpening = true

        for (index, block) in chapter.blocks.enumerated() {
            switch block {
            case .title(let runs):
                body += "<h1>\(XHTML.render(runs))</h1>\n"
                nextIsOpening = true
            case .subhead(let runs):
                // A subhead sitting directly under the chapter's opening
                // heading reads as its subtitle rather than a mid-chapter break.
                let isSubtitle = index == 1 && chapter.blocks.first?.isTitle == true
                let cls = isSubtitle ? "chapter-subtitle" : "subhead"
                body += "<h2 class=\"\(cls)\">\(XHTML.render(runs))</h2>\n"
                nextIsOpening = true
            case .paragraph(let runs):
                let cls = nextIsOpening ? " class=\"opening\"" : ""
                body += "<p\(cls)>\(XHTML.render(runs))</p>\n"
                nextIsOpening = false
            case .sceneBreak:
                body += "<p class=\"scene-break\" role=\"separator\">✦</p>\n"
                nextIsOpening = true
            }
        }
        body += "</section>"
        return page(title: chapter.openingHeading ?? entry.title, lang: lang, bodyXML: body)
    }

    // MARK: - Navigation

    /// Landmark labels are the book's own strings (its title, its contents
    /// heading, its first act's name); `epub:type` is what actually tells a
    /// reading system what each one is.
    private static func navXHTML(bookInfo: BookInfo, heading: String, acts: [ActGroup], lang: String, cover: CoverImage?) -> String {
        var toc = "<nav epub:type=\"toc\" id=\"toc\">\n<h1>\(XHTML.escape(heading))</h1>\n<ol>\n"
        for group in acts {
            toc += "<li><a href=\"\(group.actHref)\">\(XHTML.escape(group.act.name))</a>\n<ol>\n"
            for ref in group.chapters {
                toc += "<li><a href=\"\(ref.href)\">\(XHTML.escape(ref.entry.title))</a></li>\n"
            }
            toc += "</ol></li>\n"
        }
        toc += "</ol>\n</nav>\n"

        var landmarks = "<nav epub:type=\"landmarks\" id=\"landmarks\" class=\"landmarks\" hidden=\"\">\n<ol>\n"
        if cover != nil {
            landmarks += "<li><a epub:type=\"cover\" href=\"text/cover.xhtml\">\(XHTML.escape(bookInfo.title))</a></li>\n"
        }
        landmarks += "<li><a epub:type=\"titlepage\" href=\"text/titlepage.xhtml\">\(XHTML.escape(bookInfo.title))</a></li>\n"
        landmarks += "<li><a epub:type=\"toc\" href=\"nav.xhtml\">\(XHTML.escape(heading))</a></li>\n"
        if let firstAct = acts.first {
            landmarks += "<li><a epub:type=\"bodymatter\" href=\"\(firstAct.actHref)\">\(XHTML.escape(firstAct.act.name))</a></li>\n"
        }
        landmarks += "</ol>\n</nav>"

        return page(title: heading, lang: lang, cssHref: "css/stylesheet.css", bodyXML: toc + landmarks)
    }

    private static func tocNCX(bookInfo: BookInfo, heading: String, acts: [ActGroup], lang: String, identifier: String) -> String {
        var playOrder = 0
        func nextOrder() -> Int { playOrder += 1; return playOrder }

        func navPoint(id: String, order: Int, label: String, href: String) -> String {
            """
            <navPoint id="\(id)" playOrder="\(order)">
            <navLabel><text>\(XHTML.escape(label))</text></navLabel>
            <content src="\(href)"/>
            </navPoint>
            """
        }

        var navPoints = ""
        navPoints += navPoint(id: "titlepage", order: nextOrder(), label: bookInfo.title, href: "text/titlepage.xhtml")
        navPoints += navPoint(id: "navtoc", order: nextOrder(), label: heading, href: "nav.xhtml")

        for group in acts {
            let actOrder = nextOrder()
            var children = ""
            for ref in group.chapters {
                children += navPoint(id: ref.id, order: nextOrder(), label: ref.entry.title, href: ref.href)
            }
            navPoints += """
            <navPoint id="\(group.actID)" playOrder="\(actOrder)">
            <navLabel><text>\(XHTML.escape(group.act.name))</text></navLabel>
            <content src="\(group.actHref)"/>
            \(children)
            </navPoint>
            """
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" xml:lang="\(lang)">
        <head>
        <meta name="dtb:uid" content="\(identifier)"/>
        <meta name="dtb:depth" content="2"/>
        <meta name="dtb:totalPageCount" content="0"/>
        <meta name="dtb:maxPageNumber" content="0"/>
        </head>
        <docTitle><text>\(XHTML.escape(bookInfo.title))</text></docTitle>
        <navMap>
        \(navPoints)
        </navMap>
        </ncx>
        """
    }

    // MARK: - Package document

    private static func contentOPF(
        bookInfo: BookInfo,
        lang: String,
        identifier: String,
        manifest: [ManifestItem],
        spineIDs: [String],
        heading: String,
        firstAct: ActGroup?,
        cover: CoverImage?
    ) -> String {
        let now = ISO8601DateFormatter().string(from: Date())

        var manifestXML = ""
        for item in manifest {
            let props = item.properties.map { " properties=\"\($0)\"" } ?? ""
            manifestXML += "<item id=\"\(item.id)\" href=\"\(item.href)\" media-type=\"\(item.mediaType)\"\(props)/>\n"
        }

        var spineXML = ""
        for id in spineIDs {
            spineXML += "<itemref idref=\"\(id)\"/>\n"
        }

        var meta = ""
        meta += "<dc:identifier id=\"pub-id\">\(XHTML.escape(identifier))</dc:identifier>\n"
        if cover != nil {
            // EPUB2-compatibility cover pointer — many reading systems still
            // look for this even though the manifest item's "cover-image"
            // property (EPUB3) is the modern way to say the same thing.
            meta += "<meta name=\"cover\" content=\"cover-image\"/>\n"
        }
        // The "main" refinement is what tells a reading system which of several
        // dc:title elements is the book's actual title. EPUB3 makes it optional
        // and epubcheck stays silent without it, but Amazon's converter hard
        // fails on a package carrying a subtitle and no main title
        // (E20006 -> E21011 "The book title was not set"), which surfaces on
        // KDP as a generic "we couldn't convert your file".
        meta += "<dc:title id=\"main-title\">\(XHTML.escape(bookInfo.title))</dc:title>\n"
        meta += "<meta refines=\"#main-title\" property=\"title-type\">main</meta>\n"
        meta += "<meta refines=\"#main-title\" property=\"display-seq\">1</meta>\n"
        if let subtitle = bookInfo.subtitle {
            meta += "<dc:title id=\"subtitle\">\(XHTML.escape(subtitle))</dc:title>\n"
            meta += "<meta refines=\"#subtitle\" property=\"title-type\">subtitle</meta>\n"
            meta += "<meta refines=\"#subtitle\" property=\"display-seq\">2</meta>\n"
        }
        meta += "<dc:creator id=\"creator\">\(XHTML.escape(bookInfo.author))</dc:creator>\n"
        meta += "<meta refines=\"#creator\" property=\"role\" scheme=\"marc:relators\">aut</meta>\n"
        meta += "<dc:language>\(lang)</dc:language>\n"
        // Symbol, year and name only: the wording of a rights statement is the
        // author's, and lives on the copyright page in bookinfo.md.
        meta += "<dc:rights>© \(bookInfo.copyrightYear) \(XHTML.escape(bookInfo.author))</dc:rights>\n"
        meta += "<meta property=\"dcterms:modified\">\(now)</meta>\n"

        var guideXML = ""
        if cover != nil {
            guideXML += "<reference type=\"cover\" title=\"\(XHTML.escape(bookInfo.title))\" href=\"text/cover.xhtml\"/>\n"
        }
        guideXML += "<reference type=\"toc\" title=\"\(XHTML.escape(heading))\" href=\"nav.xhtml\"/>\n"
        guideXML += "<reference type=\"title-page\" title=\"\(XHTML.escape(bookInfo.title))\" href=\"text/titlepage.xhtml\"/>\n"
        if let firstAct = firstAct {
            guideXML += "<reference type=\"text\" title=\"\(XHTML.escape(firstAct.act.name))\" href=\"\(firstAct.actHref)\"/>\n"
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id" xml:lang="\(lang)">
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
        \(meta)
        </metadata>
        <manifest>
        \(manifestXML)
        </manifest>
        <spine toc="ncx">
        \(spineXML)
        </spine>
        <guide>
        \(guideXML)
        </guide>
        </package>
        """
    }

    // MARK: - Stylesheet

    private static let stylesheet = """
    body {
      font-family: Georgia, "Times New Roman", serif;
      line-height: 1.5;
      margin: 0 5%;
    }

    h1 {
      text-align: center;
      font-size: 1.5em;
      font-weight: normal;
      letter-spacing: 0.05em;
      margin: 3em 0 0.3em;
    }

    h2.chapter-subtitle {
      text-align: center;
      font-size: 1.1em;
      font-style: italic;
      font-weight: normal;
      margin: 0 0 2em;
    }

    h2.subhead {
      text-align: center;
      font-size: 1.1em;
      font-style: italic;
      font-weight: normal;
      margin: 1.6em 0 1em;
    }

    p {
      margin: 0;
      text-indent: 1.5em;
      text-align: justify;
    }

    p.opening {
      text-indent: 0;
    }

    p.scene-break {
      text-align: center;
      text-indent: 0;
      /* "3x newline; centered ✦; 3x newline" — two blank lines' worth of
         margin on each side, the reflowable-epub equivalent of literal
         empty paragraphs. */
      margin: 3em 0;
    }

    section.cover {
      margin: 0 -5%;
      padding: 0;
      text-align: center;
    }

    section.cover img {
      display: block;
      margin: 0 auto;
      max-width: 100%;
      max-height: 100vh;
      width: auto;
      height: auto;
    }

    section.titlepage,
    section.copyright,
    section.act-divider {
      text-align: center;
      margin-top: 30%;
    }

    section.titlepage h1 {
      font-size: 2em;
      text-transform: uppercase;
    }

    p.subtitle {
      font-style: italic;
      margin-top: 0.5em;
    }

    p.author {
      margin-top: 2em;
      font-size: 1.1em;
    }

    section.copyright p {
      text-indent: 0;
      text-align: center;
      margin: 0.2em 0;
    }

    p.spacer {
      margin: 1em 0;
    }

    nav ol {
      list-style: none;
      padding-left: 1em;
    }

    nav li {
      margin: 0.4em 0;
    }

    nav.landmarks {
      display: none;
    }
    """
}
