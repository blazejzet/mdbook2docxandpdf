import Foundation

/// The book's cover image. Resolution rules:
///  - `--cover <file>` given explicitly: must exist, or it's an error.
///  - not given: looks for `cover.jpg` inside --book; silently omits the
///    cover if that file isn't there (covers are optional).
/// The image itself is never resized — it's copied byte-for-byte into the
/// EPUB and the stylesheet scales it to fit whatever screen/reader displays
/// it, so any source resolution or trim size works without preprocessing.
struct CoverImage {
    let sourceURL: URL
    let mediaType: String
    let href: String   // relative to OEBPS/, e.g. "images/cover.jpg"

    static func resolve(explicitPath: URL?, bookDir: URL) throws -> CoverImage? {
        let fm = FileManager.default
        let candidate: URL
        let isExplicit: Bool
        if let explicitPath = explicitPath {
            candidate = explicitPath
            isExplicit = true
        } else {
            candidate = bookDir.appendingPathComponent("cover.jpg")
            isExplicit = false
        }

        guard fm.fileExists(atPath: candidate.path) else {
            if isExplicit {
                throw BuildError("cover image not found: \(candidate.path)")
            }
            return nil
        }

        let ext = candidate.pathExtension.lowercased()
        guard let mediaType = mediaType(forExtension: ext) else {
            throw BuildError("unsupported cover image format: \(candidate.lastPathComponent) (use .jpg, .jpeg, .png, .gif or .svg)")
        }

        return CoverImage(sourceURL: candidate, mediaType: mediaType, href: "images/cover.\(ext)")
    }

    private static func mediaType(forExtension ext: String) -> String? {
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        default: return nil
        }
    }
}
