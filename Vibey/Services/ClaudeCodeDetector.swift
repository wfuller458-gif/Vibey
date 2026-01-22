//
//  ClaudeCodeDetector.swift
//  Vibey
//
//  Detects if Claude Code CLI is installed and provides installation
//

import Foundation
import Combine

class ClaudeCodeDetector: ObservableObject {
    @Published var isInstalled: Bool = false
    @Published var claudePath: String?
    @Published var isChecking: Bool = false
    @Published var isInstalling: Bool = false
    @Published var installError: String?

    // Check if Claude Code is installed
    func checkInstallation() {
        isChecking = true

        Task {
            // Run 'which claude' in a login shell to access user's PATH
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let command: String

            if shell.contains("zsh") {
                command = "zsh -l -c 'which claude'"
            } else if shell.contains("bash") {
                command = "bash -l -c 'which claude'"
            } else {
                command = "sh -c 'which claude'"
            }

            let result = await runCommand(command)

            // DEBUG: Print what we got
            print("DEBUG: Detection command: \(command)")
            print("DEBUG: Detection result: '\(result)'")

            DispatchQueue.main.async {
                self.isChecking = false

                if !result.isEmpty && !result.contains("not found") {
                    // Found it!
                    self.claudePath = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.isInstalled = true
                    print("DEBUG: Claude Code FOUND at: \(self.claudePath ?? "unknown")")
                } else {
                    // Not found
                    self.isInstalled = false
                    self.claudePath = nil
                    print("DEBUG: Claude Code NOT FOUND")
                }
            }
        }
    }

    // Install Claude Code via npm
    func installClaudeCode() {
        isInstalling = true
        installError = nil

        Task {
            // First check if npm is installed
            let npmCheck = await runCommand("which npm")

            if npmCheck.isEmpty || npmCheck.contains("not found") {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.installError = "npm not found. Please install Node.js first."
                }
                return
            }

            // Install Claude Code globally
            let result = await runCommand("npm install -g @anthropic-ai/claude-code")

            DispatchQueue.main.async {
                self.isInstalling = false

                if result.contains("added") || result.contains("updated") {
                    // Success! Check again to confirm
                    self.checkInstallation()
                } else {
                    self.installError = "Installation failed. Please install manually."
                }
            }
        }
    }

    // Get the user's actual PATH from their shell
    func getUserShellPath() async -> String {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let command: String

        if shell.contains("zsh") {
            command = "zsh -l -c 'echo $PATH'"
        } else if shell.contains("bash") {
            command = "bash -l -c 'echo $PATH'"
        } else {
            command = "sh -c 'echo $PATH'"
        }

        let result = await runCommand(command)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Helper to run shell commands
    private func runCommand(_ command: String) async -> String {
        return await withCheckedContinuation { continuation in
            let task = Process()
            let pipe = Pipe()

            task.standardOutput = pipe
            task.standardError = pipe
            task.arguments = ["-c", command]
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.standardInput = nil

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                continuation.resume(returning: output)
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}
