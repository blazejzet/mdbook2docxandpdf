import Foundation

/// Low-level WordprocessingML string builders. Kept deliberately dumb (plain
/// string concatenation) — there is no XML tree here, just enough structure
/// to keep call sites readable and escaping centralized.
enum OOXML {

    static func escape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            default: out.append(ch)
            }
        }
        return out
    }

    /// A single text run. `xml:space="preserve"` is always set since chapter
    /// text may carry leading/trailing spaces around em dashes.
    static func run(_ text: String, styleId: String? = nil, bold: Bool = false, italic: Bool = false) -> String {
        var rPr = ""
        if styleId != nil || bold || italic {
            var inner = ""
            if let styleId = styleId { inner += "<w:rStyle w:val=\"\(styleId)\"/>" }
            if bold { inner += "<w:b/>" }
            if italic { inner += "<w:i/>" }
            rPr = "<w:rPr>\(inner)</w:rPr>"
        }
        return "<w:r>\(rPr)<w:t xml:space=\"preserve\">\(escape(text))</w:t></w:r>"
    }

    /// A sequence of runs from parsed inline markdown (`**bold**`,
    /// `*italic*`) — each `InlineRun` becomes its own `<w:r>` with direct
    /// `<w:b/>`/`<w:i/>` formatting, no character style needed.
    static func runs(_ inlineRuns: [InlineRun]) -> String {
        inlineRuns.map { run($0.text, bold: $0.bold, italic: $0.italic) }.joined()
    }

    /// A paragraph. `sectPr` (when present) closes out a section at this
    /// paragraph — see `Section.swift`.
    static func paragraph(style: String?, jc: String? = nil, extraPPr: String = "", runsXML: String, sectPr: String? = nil) -> String {
        var pPr = ""
        var inner = ""
        if let style = style { inner += "<w:pStyle w:val=\"\(style)\"/>" }
        if let jc = jc { inner += "<w:jc w:val=\"\(jc)\"/>" }
        inner += extraPPr
        if let sectPr = sectPr { inner += sectPr }
        if !inner.isEmpty { pPr = "<w:pPr>\(inner)</w:pPr>" }
        return "<w:p>\(pPr)\(runsXML)</w:p>"
    }

    static func emptyParagraph(style: String?, sectPr: String? = nil) -> String {
        paragraph(style: style, runsXML: "", sectPr: sectPr)
    }

    static func bookmarkStart(id: Int, name: String) -> String {
        "<w:bookmarkStart w:id=\"\(id)\" w:name=\"\(name)\"/>"
    }

    static func bookmarkEnd(id: Int) -> String {
        "<w:bookmarkEnd w:id=\"\(id)\"/>"
    }

    /// A live `PAGE` field run sequence, centered wherever it's placed.
    static func pageFieldRuns(styleId: String = "PageNumber") -> String {
        fieldRuns(instruction: " PAGE ", cachedResult: "1", styleId: styleId)
    }

    /// A live `PAGEREF <bookmark> \h` field run sequence (hyperlinked page number).
    static func pageRefFieldRuns(bookmark: String, styleId: String? = nil) -> String {
        fieldRuns(instruction: " PAGEREF \(bookmark) \\h ", cachedResult: "1", styleId: styleId)
    }

    private static func fieldRuns(instruction: String, cachedResult: String, styleId: String?) -> String {
        let rPr: String
        if let styleId = styleId {
            rPr = "<w:rPr><w:rStyle w:val=\"\(styleId)\"/></w:rPr>"
        } else {
            rPr = ""
        }
        return """
        <w:r>\(rPr)<w:fldChar w:fldCharType="begin"/></w:r>\
        <w:r>\(rPr)<w:instrText xml:space="preserve">\(instruction)</w:instrText></w:r>\
        <w:r>\(rPr)<w:fldChar w:fldCharType="separate"/></w:r>\
        <w:r>\(rPr)<w:t>\(cachedResult)</w:t></w:r>\
        <w:r>\(rPr)<w:fldChar w:fldCharType="end"/></w:r>
        """
    }

    /// A right-aligned dot-leader tab stop, positioned near the text margin.
    static func tocTab(pos: Int) -> String {
        "<w:tabs><w:tab w:val=\"right\" w:leader=\"dot\" w:pos=\"\(pos)\"/></w:tabs>"
    }

    static func tabRun() -> String {
        "<w:r><w:tab/></w:r>"
    }
}
