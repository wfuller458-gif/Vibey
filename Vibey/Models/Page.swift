//
//  Page.swift
//  Vibey
//
//  Represents a markdown-style note/page within a project
//

import Foundation

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

    // Markdown-style content (headings, text, lists, checkboxes)
    var content: String

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
        content: String = "",
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
}
