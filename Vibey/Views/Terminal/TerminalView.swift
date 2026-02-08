//
//  TerminalView.swift
//  Vibey
//
//  Main terminal view with toolbar and SwiftTerm integration
//  Displays functional terminal with directory info and controls
//

import SwiftUI

struct TerminalView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var terminalState: TerminalState
    let projectID: UUID
    let isComicSansMode: Bool
    @State private var showingClearConfirmation = false
    @State private var terminalKey = UUID() // For forcing terminal restart
    @State private var showSetupHelp = true // Start expanded, can be toggled

    var body: some View {
        VStack(spacing: 0) {
            // Minimal toolbar with clear button and help toggle
            HStack {
                // Show help toggle button when help is hidden
                if !showSetupHelp {
                    Button(action: {
                        withAnimation {
                            showSetupHelp = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.vibeyBlue)

                            Text("Show Setup Help")
                                .font(.atkinsonRegular(size: 12))
                                .foregroundColor(.vibeyBlue)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: {
                    showingClearConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.vibeyText.opacity(0.7))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Clear terminal")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "1C1E22"))

            // Setup help panel (collapsible)
            if showSetupHelp {
                ClaudeCodeHelpPanel(onDismiss: {
                    withAnimation {
                        showSetupHelp = false
                    }
                })
            }

            // Terminal content (SwiftTerm)
            SwiftTermWrapper(
                terminalState: terminalState,
                isComicSansMode: isComicSansMode,
                onBell: handleBell
            )
            .id(terminalKey) // Use key to force recreation on restart
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Message input editor
            TerminalMessageEditor(
                terminalState: terminalState,
                isComicSansMode: isComicSansMode
            )
        }
        .background(Color.vibeyBackground)
        .alert("Clear Terminal?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearTerminal()
            }
        } message: {
            Text("This will clear the terminal output and restart the session.")
        }
    }

    private func handleBell() {
        // Visual bell effect - play system beep
        NSSound.beep()
    }

    private func restartTerminal() {
        // Force terminal to restart by changing the key
        terminalState.isRunning = false
        terminalKey = UUID()
    }

    private func clearTerminal() {
        // Clear all page statuses for this project
        appState.clearAllPageStatuses(for: projectID)

        // Restart terminal which effectively clears it
        restartTerminal()
    }
}

// MARK: - Terminal Toolbar

struct TerminalToolbar: View {
    let workingDirectory: String
    let isRunning: Bool
    let onClear: () -> Void
    let onRestart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Working directory indicator
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.vibeyBlue)

                Text(shortenedPath)
                    .font(.atkinsonRegular(size: 12))
                    .foregroundColor(.vibeyText.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(isRunning ? "Running" : "Stopped")
                    .font(.atkinsonRegular(size: 12))
                    .foregroundColor(.vibeyText.opacity(0.7))
            }

            // Clear button
            Button(action: onClear) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.vibeyText.opacity(0.7))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Clear terminal")

            // Restart button
            Button(action: onRestart) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(.vibeyText.opacity(0.7))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Restart terminal")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "1C1E22"))
        .overlay(
            Rectangle()
                .fill(Color.vibeyCardBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var shortenedPath: String {
        workingDirectory.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

// MARK: - Claude Code Help Panel

struct ClaudeCodeHelpPanel: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.vibeyBlue)

                Text("Getting Claude Code Working")
                    .font(.atkinsonRegular(size: 14))
                    .fontWeight(.bold)
                    .foregroundColor(.vibeyBlue)
                    .kerning(0.98)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Hide help")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "1C1E22"))

            // Steps
            VStack(alignment: .leading, spacing: 0) {
                // Step 1: Get Started
                HelpStepRow(
                    title: "Get Started",
                    description: "Type the following command in the terminal below to launch Claude.",
                    command: "claude",
                    showDivider: true
                )

                // Step 2: Check Installation
                HelpStepRow(
                    title: "Check Installation",
                    description: "If nothing happens, verify Claude Code is installed by running this command.",
                    command: "claude --version",
                    showDivider: true
                )

                // Step 3: Need to Install?
                HelpStepRow(
                    title: "Need to Install?",
                    description: "Follow the official installation guide to set up Claude Code on your system.",
                    linkText: "Claude Code Installation Guide",
                    linkURL: "https://docs.anthropic.com/en/docs/claude-code/getting-started",
                    showDivider: false
                )
            }
            .padding(.vertical, 8)
            .background(Color.vibeyBackground)
        }
        .overlay(
            Rectangle()
                .fill(Color.vibeyCardBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Help Step Row

struct HelpStepRow: View {
    let title: String
    let description: String
    var command: String? = nil
    var linkText: String? = nil
    var linkURL: String? = nil
    let showDivider: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(title)
                        .font(.atkinsonRegular(size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(.vibeyText)

                    // Description
                    Text(description)
                        .font(.atkinsonRegular(size: 12))
                        .foregroundColor(.vibeyText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)

                    // Command with copy button (if provided)
                    if let command = command {
                        HStack(spacing: 8) {
                            Text(command)
                                .font(.custom("SF Mono", size: 11))
                                .foregroundColor(.vibeyBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "1C1E22"))
                                .cornerRadius(4)

                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(command, forType: .string)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11))
                                    .foregroundColor(.vibeyText.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .help("Copy to clipboard")
                        }
                        .padding(.top, 4)
                    }

                    // Link (if provided)
                    if let linkText = linkText, let linkURL = linkURL {
                        Button(action: {
                            if let url = URL(string: linkURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(linkText)
                                    .font(.atkinsonRegular(size: 12))
                                    .foregroundColor(.vibeyBlue)

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.vibeyBlue)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Divider
            if showDivider {
                Rectangle()
                    .fill(Color.vibeyCardBorder)
                    .frame(height: 1)
                    .padding(.leading, 16)
            }
        }
    }
}


#Preview {
    TerminalView(terminalState: TerminalState(), projectID: UUID(), isComicSansMode: false)
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
