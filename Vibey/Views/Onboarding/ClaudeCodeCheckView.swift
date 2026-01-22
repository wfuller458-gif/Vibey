//
//  ClaudeCodeCheckView.swift
//  Vibey
//
//  Validates that Claude Code CLI is installed and authenticated
//  Shows setup guide if missing
//

import SwiftUI

struct ClaudeCodeCheckView: View {
    let onComplete: () -> Void

    @State private var isChecking = true
    @State private var claudeCodeInstalled = false
    @State private var checkMessage = "Checking for Claude Code..."

    var body: some View {
        ZStack {
            // Background
            Color.vibeyBackground
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 64) {
                VibeyLogo()

                if isChecking {
                    // Checking state
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .vibeyBlue))

                        Text(checkMessage)
                            .font(.atkinsonRegular(size: 18))
                            .foregroundColor(.vibeyText)
                    }
                } else if claudeCodeInstalled {
                    // Success state
                    VStack(spacing: 32) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)

                        VStack(spacing: 16) {
                            Text("All Set!")
                                .font(.atkinsonBold(size: 32))
                                .foregroundColor(.vibeyText)

                            Text("Claude Code is installed and ready to use")
                                .font(.atkinsonRegular(size: 18))
                                .foregroundColor(.vibeyText.opacity(0.7))
                        }

                        Button(action: onComplete) {
                            Text("Get Started")
                                .font(.atkinsonBold(size: 18))
                                .foregroundColor(.white)
                                .frame(width: 400)
                                .frame(height: 50)
                                .background(Color.vibeyBlue)
                                .cornerRadius(CornerRadius.button)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Claude Code not found - show setup guide
                    VStack(spacing: 32) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.orange)

                        VStack(spacing: 16) {
                            Text("Claude Code Not Found")
                                .font(.atkinsonBold(size: 32))
                                .foregroundColor(.vibeyText)

                            Text("Please install Claude Code to continue")
                                .font(.atkinsonRegular(size: 18))
                                .foregroundColor(.vibeyText.opacity(0.7))
                        }

                        // Setup instructions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Installation Steps:")
                                .font(.atkinsonBold(size: 16))
                                .foregroundColor(.vibeyText)

                            VStack(alignment: .leading, spacing: 12) {
                                InstructionRow(
                                    number: "1",
                                    text: "Open Terminal"
                                )
                                InstructionRow(
                                    number: "2",
                                    text: "Run: brew install claude-code"
                                )
                                InstructionRow(
                                    number: "3",
                                    text: "Authenticate with: claude auth login"
                                )
                            }
                        }
                        .padding(24)
                        .frame(width: 500)
                        .background(Color.vibeyCardBorder)
                        .cornerRadius(CornerRadius.medium)

                        HStack(spacing: 16) {
                            // Recheck button
                            Button(action: checkClaudeCode) {
                                Text("Check Again")
                                    .font(.atkinsonBold(size: 16))
                                    .foregroundColor(.vibeyText)
                                    .frame(width: 180)
                                    .frame(height: 44)
                                    .background(Color.vibeyCardBorder)
                                    .cornerRadius(CornerRadius.button)
                            }
                            .buttonStyle(.plain)

                            // Skip button (proceed anyway)
                            Button(action: onComplete) {
                                Text("Skip for Now")
                                    .font(.atkinsonBold(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 180)
                                    .frame(height: 44)
                                    .background(Color.vibeyBlue)
                                    .cornerRadius(CornerRadius.button)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear {
            checkClaudeCode()
        }
    }

    // Check if Claude Code is installed
    func checkClaudeCode() {
        isChecking = true
        checkMessage = "Checking for Claude Code..."

        // Use Task for async operation
        Task {
            // Wait a moment for better UX
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // Check if claude command exists
            let result = await runShellCommand("which claude")

            await MainActor.run {
                claudeCodeInstalled = !result.isEmpty
                isChecking = false
            }
        }
    }

    // Helper to run shell commands
    func runShellCommand(_ command: String) async -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.standardInput = nil

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

// Instruction row component
struct InstructionRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.atkinsonBold(size: 14))
                .foregroundColor(.vibeyBlue)
                .frame(width: 24, height: 24)
                .background(Color.vibeyBlue.opacity(0.15))
                .cornerRadius(12)

            Text(text)
                .font(.atkinsonRegular(size: 16))
                .foregroundColor(.vibeyText)
        }
    }
}

#Preview {
    ClaudeCodeCheckView(onComplete: {})
}
