import Foundation

/// One styled segment of a paragraph's text after inline markdown has been
/// resolved — everything between (or outside) `*`/`_` emphasis markers.
struct InlineRun {
    let text: String
    let bold: Bool
    let italic: Bool
}

/// A deliberately minimal inline-markdown parser: `**bold**`, `*italic*`,
/// `***bold italic***` and their `_underscore_` equivalents. No links, code
/// spans, or emphasis nested inside a different delimiter type — this is
/// manuscript prose, not general markdown, and that's the full extent of
/// what shows up in it.
enum InlineMarkdown {
    static func parse(_ text: String) -> [InlineRun] {
        let chars = Array(text)
        var runs: [InlineRun] = []
        var buffer = ""
        var i = 0

        func flushPlain() {
            guard !buffer.isEmpty else { return }
            runs.append(InlineRun(text: buffer, bold: false, italic: false))
            buffer = ""
        }

        while i < chars.count {
            let ch = chars[i]
            guard ch == "*" || ch == "_" else {
                buffer.append(ch)
                i += 1
                continue
            }

            let marker = ch
            var openEnd = i
            while openEnd < chars.count && chars[openEnd] == marker { openEnd += 1 }
            let runLength = openEnd - i
            let delimiterLength = min(runLength, 3)

            // CommonMark-style guards: `_` doesn't open mid-word (avoids
            // `foo_bar_baz`), and a delimiter run followed by whitespace
            // isn't a valid opener (avoids " * " read as emphasis).
            let isWordChar: (Character) -> Bool = { $0.isLetter || $0.isNumber }
            let precededByWord = i > 0 && isWordChar(chars[i - 1])
            let followedByWord = openEnd < chars.count && isWordChar(chars[openEnd])
            let validOpener = openEnd < chars.count && !chars[openEnd].isWhitespace
                && !(marker == "_" && precededByWord && followedByWord)

            if validOpener, let close = findCloser(chars, openEnd: openEnd, marker: marker, length: delimiterLength) {
                flushPlain()
                let inner = String(chars[openEnd..<close])
                runs.append(InlineRun(text: inner, bold: delimiterLength >= 2, italic: delimiterLength == 1 || delimiterLength == 3))
                let leftover = runLength - delimiterLength
                if leftover > 0 {
                    buffer += String(repeating: String(marker), count: leftover)
                }
                i = close + delimiterLength
            } else {
                buffer += String(repeating: String(marker), count: runLength)
                i = openEnd
            }
        }
        flushPlain()
        return runs
    }

    /// Finds the next run of `marker` at least `length` long, at least one
    /// character after `openEnd`, whose preceding character isn't
    /// whitespace (the closing-delimiter mirror of the opener guard above).
    private static func findCloser(_ chars: [Character], openEnd: Int, marker: Character, length: Int) -> Int? {
        var k = openEnd
        while k < chars.count {
            if chars[k] == marker {
                var runEnd = k
                while runEnd < chars.count && chars[runEnd] == marker { runEnd += 1 }
                if runEnd - k >= length, k > openEnd, !chars[k - 1].isWhitespace {
                    return k
                }
                k = runEnd
            } else {
                k += 1
            }
        }
        return nil
    }
}

extension Array where Element == InlineRun {
    /// The runs' text with the emphasis dropped — for the places that need a
    /// bare string (an XHTML `<title>`, a log line) rather than styled runs.
    var plainText: String {
        map(\.text).joined()
    }
}
