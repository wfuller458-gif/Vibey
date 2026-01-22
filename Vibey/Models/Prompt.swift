//
//  Prompt.swift
//  Vibey
//
//  Represents a draft prompt in the Prompt Planner
//  Allows users to compose prompts with full editing before sending to terminal
//

import Foundation

struct Prompt: Identifiable, Codable {
    // Unique identifier
    let id: UUID

    // Which project this prompt belongs to
    let projectID: UUID

    // Prompt content (full text with spellcheck, undo support)
    var content: String

    // When the prompt was created
    let createdAt: Date

    // Last modification time
    var updatedAt: Date

    // TODO: Add CloudKit sync later
    // var cloudKitRecordID: CKRecord.ID?

    // Initialize a new prompt
    init(
        id: UUID = UUID(),
        projectID: UUID,
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
