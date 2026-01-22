//
//  TerminalState.swift
//  Vibey
//
//  Terminal session state management
//  Tracks working directory, command history, and process state per project
//

import Foundation
import Combine

class TerminalState: ObservableObject, Codable {
    @Published var processID: Int32?
    @Published var workingDirectory: String
    @Published var environmentVariables: [String: String]
    @Published var commandHistory: [String]
    @Published var isRunning: Bool
    @Published var currentCommand: String
    @Published var textToSend: String = ""

    // Coding keys for persistence (exclude @Published wrappers)
    enum CodingKeys: String, CodingKey {
        case workingDirectory
        case environmentVariables
        case commandHistory
    }

    init(workingDirectory: String = NSHomeDirectory()) {
        self.workingDirectory = workingDirectory
        self.environmentVariables = ProcessInfo.processInfo.environment as [String: String]
        self.commandHistory = []
        self.isRunning = false
        self.currentCommand = ""
        self.processID = nil
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
        self.environmentVariables = try container.decode([String: String].self, forKey: .environmentVariables)
        self.commandHistory = try container.decode([String].self, forKey: .commandHistory)

        // Non-persisted properties
        self.isRunning = false
        self.currentCommand = ""
        self.processID = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workingDirectory, forKey: .workingDirectory)
        try container.encode(environmentVariables, forKey: .environmentVariables)
        try container.encode(commandHistory, forKey: .commandHistory)
    }

    // MARK: - Command History Management

    func addToHistory(_ command: String) {
        guard !command.isEmpty else { return }
        commandHistory.append(command)
        // Keep last 1000 commands
        if commandHistory.count > 1000 {
            commandHistory.removeFirst()
        }
    }

    func getPreviousCommand(offset: Int) -> String? {
        let index = commandHistory.count - 1 - offset
        guard index >= 0 && index < commandHistory.count else { return nil }
        return commandHistory[index]
    }

    func clearHistory() {
        commandHistory.removeAll()
    }

    // MARK: - Send Text to Terminal

    func sendText(_ text: String) {
        self.textToSend = text
    }
}
