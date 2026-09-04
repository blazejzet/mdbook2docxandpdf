import Foundation

/// The handful of template parts we reuse verbatim: they carry the actual
/// visual design (fonts, styles, theme colors) that makes the output match
/// "5 x 8_English.docx". Everything content-shaped (document.xml, headers,
/// footers, docProps) is generated fresh by PartsBuilder/DocumentBuilder.
struct TemplateAssets {
    let stylesXML: String
    let themeXML: String
    let fontTableXML: String
    let webSettingsXML: String
    let settingsXML: String
    let footnotesXML: String
    let endnotesXML: String

    static func load(templateDocx: URL, workDir: URL) throws -> TemplateAssets {
        let extractDir = workDir.appendingPathComponent("template-extract")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try ZipTool.extract(archive: templateDocx, to: extractDir)

        func read(_ relativePath: String) throws -> String {
            let url = extractDir.appendingPathComponent(relativePath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw BuildError("Template is missing expected part: \(relativePath)")
            }
            return try String(contentsOf: url, encoding: .utf8)
        }

        return TemplateAssets(
            stylesXML: try read("word/styles.xml"),
            themeXML: try read("word/theme/theme1.xml"),
            fontTableXML: try read("word/fontTable.xml"),
            webSettingsXML: try read("word/webSettings.xml"),
            settingsXML: try read("word/settings.xml"),
            footnotesXML: try read("word/footnotes.xml"),
            endnotesXML: try read("word/endnotes.xml")
        )
    }
}
