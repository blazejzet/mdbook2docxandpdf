import Foundation

/// Relationship IDs for the handful of header/footer parts every section
/// references. Fixed and shared — see PartsBuilder for how they're wired
/// into word/_rels/document.xml.rels.
enum RID {
    static let styles = "rId1"
    static let settings = "rId2"
    static let webSettings = "rId3"
    static let fontTable = "rId4"
    static let theme = "rId5"
    static let footnotes = "rId6"
    static let endnotes = "rId7"
    static let headerBlank = "rId8"
    static let headerDefault = "rId9"   // recto pages: book title
    static let headerEven = "rId10"     // verso pages: author name
    static let footerBlank = "rId11"
    static let footerPageNumber = "rId12"
}

enum PageNumberFormat {
    /// Decimal, continuing the running count. Omitting `<w:pgNumType>`
    /// entirely defaults to decimal in OOXML, so this needs no element.
    case decimalContinued
    /// Roman, continuing the running count. Unlike decimal, the *format*
    /// does not carry over from a previous section on its own — leaving
    /// `<w:pgNumType>` out here would silently fall back to decimal even
    /// though the counter kept incrementing. So this still emits
    /// `fmt="lowerRoman"`, just without a `start` (which is what actually
    /// resets the counter).
    case lowerRomanContinued
    case lowerRoman(start: Int)
    case decimal(start: Int)
}

/// Page geometry for the 5"x8" trim size (in twips: 1/1440 inch).
enum PageGeometry {
    static let width = 7200
    static let height = 11520
    static let marginTop = 864
    static let marginBottom = 864
    static let marginLeft = 1094
    static let marginRight = 864
    static let headerMargin = 504
    static let footerMargin = 504
    /// Usable text width, for right-tab TOC leaders.
    static let textWidth = width - marginLeft - marginRight
}

enum Section {
    /// Builds a `<w:sectPr>` for a section break. Every section is
    /// "different first page": the opening page never shows a running head,
    /// and — unless `hideFirstPageNumber` is set (title/copyright pages
    /// only) — it does show a live page number.
    static func sectPr(pageNumbers: PageNumberFormat, hideFirstPageNumber: Bool = false, vAlign: String? = nil) -> String {
        var xml = "<w:sectPr>"
        xml += "<w:headerReference w:type=\"even\" r:id=\"\(RID.headerEven)\"/>"
        xml += "<w:headerReference w:type=\"default\" r:id=\"\(RID.headerDefault)\"/>"
        xml += "<w:headerReference w:type=\"first\" r:id=\"\(RID.headerBlank)\"/>"
        let firstFooterRid = hideFirstPageNumber ? RID.footerBlank : RID.footerPageNumber
        xml += "<w:footerReference w:type=\"even\" r:id=\"\(RID.footerPageNumber)\"/>"
        xml += "<w:footerReference w:type=\"default\" r:id=\"\(RID.footerPageNumber)\"/>"
        xml += "<w:footerReference w:type=\"first\" r:id=\"\(firstFooterRid)\"/>"
        xml += "<w:pgSz w:w=\"\(PageGeometry.width)\" w:h=\"\(PageGeometry.height)\"/>"
        xml += "<w:pgMar w:top=\"\(PageGeometry.marginTop)\" w:right=\"\(PageGeometry.marginRight)\" w:bottom=\"\(PageGeometry.marginBottom)\" w:left=\"\(PageGeometry.marginLeft)\" w:header=\"\(PageGeometry.headerMargin)\" w:footer=\"\(PageGeometry.footerMargin)\" w:gutter=\"0\"/>"
        switch pageNumbers {
        case .decimalContinued:
            break
        case .lowerRomanContinued:
            xml += "<w:pgNumType w:fmt=\"lowerRoman\"/>"
        case .lowerRoman(let start):
            xml += "<w:pgNumType w:fmt=\"lowerRoman\" w:start=\"\(start)\"/>"
        case .decimal(let start):
            xml += "<w:pgNumType w:start=\"\(start)\"/>"
        }
        xml += "<w:cols w:space=\"720\"/>"
        if let vAlign = vAlign {
            xml += "<w:vAlign w:val=\"\(vAlign)\"/>"
        }
        xml += "<w:titlePg/>"
        xml += "<w:docGrid w:linePitch=\"360\"/>"
        xml += "</w:sectPr>"
        return xml
    }
}
