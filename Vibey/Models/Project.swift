//
//  Project.swift
//  Vibey
//
//  Represents a single project workspace in Vibey
//  Each project contains its own terminal session, pages, and prompts
//

import Foundation

struct Project: Identifiable, Codable {
    // Unique identifier for the project
    let id: UUID

    // Project name shown to the user
    var name: String

    // When the project was created
    let createdAt: Date

    // Last time the project was modified
    var updatedAt: Date

    // Terminal state for this project
    var terminalState: TerminalState

    // Pages belonging to this project
    var pages: [Page]

    // TODO: Add CloudKit sync later
    // var cloudKitRecordID: CKRecord.ID?

    // Initialize a new project
    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        // Initialize terminal with home directory as default
        self.terminalState = TerminalState(workingDirectory: NSHomeDirectory())
        self.pages = []
    }
}
