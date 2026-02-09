//
//  Page.swift
//  Vibey
//
//  Represents a rich text note/page within a project
//

import Foundation
import AppKit

// Status indicator for whether a page has been shared with Claude
enum PageStatus: String, Codable {
    case notShared  // Default (grey) - not shared with Claude
    case shared     // Green - shared with Claude + timestamp
    case contextLost // Red - context lost (terminal cleared or /clear used)
}

struct Page: Identifiable, Codable {
    // Unique identifier
    let id: UUID

    // Which project this page belongs to
    let projectID: UUID

    // Page title (H1)
    var title: String

    // Rich text content stored as RTF data
    var content: Data

    // When the page was created
    let createdAt: Date

    // Last modification time
    var updatedAt: Date

    // Current sharing status with Claude Code terminal
    var status: PageStatus

    // Timestamp of when it was last shared to terminal
    var sharedAt: Date?

    // TODO: Add CloudKit sync later
    // var cloudKitRecordID: CKRecord.ID?

    // Initialize a new page
    init(
        id: UUID = UUID(),
        projectID: UUID,
        title: String = "",
        content: Data = Data(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: PageStatus = .notShared,
        sharedAt: Date? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.sharedAt = sharedAt
    }

    // Legacy initializer for migration from plain text
    init(
        id: UUID = UUID(),
        projectID: UUID,
        title: String = "",
        plainTextContent: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: PageStatus = .notShared,
        sharedAt: Date? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.content = Page.rtfData(from: plainTextContent)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.sharedAt = sharedAt
    }

    // MARK: - RTF Conversion Helpers

    /// Convert content data to NSAttributedString
    var attributedString: NSAttributedString {
        if content.isEmpty {
            return NSAttributedString(string: "")
        }

        // Try NSKeyedUnarchiver first (new format with image support)
        // Use non-secure coding to allow NSTextAttachment, NSImage, etc.
        if let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: content) {
            unarchiver.requiresSecureCoding = false
            if let attrString = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString {
                return attrString
            }
        }

        // Fall back to RTF (legacy format)
        if let attrString = NSAttributedString(rtf: content, documentAttributes: nil) {
            return attrString
        }

        // Fallback: try to interpret as plain text
        if let plainText = String(data: content, encoding: .utf8) {
            return Page.defaultAttributedString(from: plainText)
        }

        return NSAttributedString(string: "")
    }

    /// Set content from NSAttributedString
    mutating func setAttributedString(_ attrString: NSAttributedString) {
        // Use NSKeyedArchiver to preserve images
        if let archivedData = try? NSKeyedArchiver.archivedData(withRootObject: attrString, requiringSecureCoding: false) {
            content = archivedData
        }
    }

    /// Get plain text for sending to terminal - strips ALL formatting but preserves line breaks
    var plainText: String {
        guard !content.isEmpty else { return "" }

        // Use the attributedString property which handles all formats (archived, RTF, plain text)
        var text = attributedString.string

        // Clean up for terminal - replace bullets, checkboxes, and tabs with plain text equivalents
        text = text.replacingOccurrences(of: "\u{2022}\t", with: "- ")
        text = text.replacingOccurrences(of: "•\t", with: "- ")
        text = text.replacingOccurrences(of: "☐\t", with: "[ ] ")
        text = text.replacingOccurrences(of: "☑\t", with: "[x] ")
        text = text.replacingOccurrences(of: "\t", with: "  ")

        // Collapse multiple spaces into one (but preserve newlines)
        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }

        // Remove any non-printable characters except newlines and spaces
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.punctuationCharacters)
            .union(CharacterSet(charactersIn: " \n"))
        text = String(text.unicodeScalars.filter { allowedCharacters.contains($0) })

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if content is empty
    var isEmpty: Bool {
        return content.isEmpty || plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Image Extraction

    /// Extract images from content and save to temp files for terminal
    /// Returns array of file paths to the saved images
    func extractImagesForTerminal() -> [String] {
        // Use the attributedString property which handles all formats
        let attrString = attributedString
        guard attrString.length > 0 else {
            return []
        }

        var imagePaths: [String] = []
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("vibey-images")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        attrString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attrString.length)) { value, _, _ in
            if let attachment = value as? NSTextAttachment,
               let image = attachment.image {
                let filename = UUID().uuidString + ".png"
                let filePath = tempDir.appendingPathComponent(filename)
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: filePath)
                    imagePaths.append(filePath.path)
                }
            }
        }
        return imagePaths
    }

    // MARK: - Static Helpers

    /// Create RTF data from plain text with default styling
    static func rtfData(from plainText: String) -> Data {
        let attrString = defaultAttributedString(from: plainText)
        return attrString.rtf(from: NSRange(location: 0, length: attrString.length), documentAttributes: [:]) ?? Data()
    }

    /// Create an attributed string with default styling
    static func defaultAttributedString(from plainText: String) -> NSAttributedString {
        // Use system font (San Francisco) for body text - has proper bold/italic support
        let font = NSFont.systemFont(ofSize: 16)
        let textColor = NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0) // vibeyText

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        return NSAttributedString(string: plainText, attributes: attributes)
    }
}
