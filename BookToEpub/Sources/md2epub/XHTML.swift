import Foundation

/// Tiny string-escaping helper — there is no XML tree here, just enough to
/// keep call sites readable and escaping centralized (mirrors md2docx's
/// OOXML.escape).
enum XHTML {
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

    /// Renders parsed inline markdown (`**bold**`, `*italic*`) as escaped
    /// text wrapped in `<strong>`/`<em>`.
    static func render(_ runs: [InlineRun]) -> String {
        var out = ""
        for run in runs {
            var segment = escape(run.text)
            if run.italic { segment = "<em>\(segment)</em>" }
            if run.bold { segment = "<strong>\(segment)</strong>" }
            out += segment
        }
        return out
    }
}
