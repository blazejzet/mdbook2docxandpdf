import Foundation
import CryptoKit

/// Publication identifier for dc:identifier. Prefers a real ISBN; falls back
/// to a UUID deterministically derived from title+author (via SHA-256) so
/// repeated builds of the same book keep a stable identifier instead of a
/// fresh random one every run.
enum Identifier {
    static func forBook(_ bookInfo: BookInfo) -> String {
        if let isbn = bookInfo.isbnDigits {
            return "urn:isbn:\(isbn)"
        }
        return "urn:uuid:\(deterministicUUID(seed: "\(bookInfo.title)|\(bookInfo.author)"))"
    }

    private static func deterministicUUID(seed: String) -> String {
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // version 5 (name-based)
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        func slice(_ from: Int, _ len: Int) -> String {
            let start = hex.index(hex.startIndex, offsetBy: from)
            let end = hex.index(start, offsetBy: len)
            return String(hex[start..<end])
        }
        return "\(slice(0, 8))-\(slice(8, 4))-\(slice(12, 4))-\(slice(16, 4))-\(slice(20, 12))"
    }
}
