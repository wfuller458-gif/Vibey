//
//  SwiftTermWrapper.swift
//  Vibey
//
//  SwiftUI wrapper for SwiftTerm's terminal emulator
//  Bridges NSView-based SwiftTerm to SwiftUI using NSViewRepresentable
//

import SwiftUI
import SwiftTerm
import Combine

struct SwiftTermWrapper: NSViewRepresentable {
    @ObservedObject var terminalState: TerminalState
    let onBell: () -> Void

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Configure terminal appearance
        // Use SF Mono for proper monospace terminal display
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // Set dark theme colors matching Vibey design - must match page background #121418
        // Using explicit RGB values to ensure exact color match
        let backgroundColor = NSColor(calibratedRed: 0x12/255.0, green: 0x14/255.0, blue: 0x18/255.0, alpha: 1.0)
        terminalView.nativeForegroundColor = NSColor(hex: "EBECF0") // vibeyText
        terminalView.nativeBackgroundColor = backgroundColor
        terminalView.caretColor = NSColor(hex: "0459FE") // vibeyBlue

        // Ensure the view's layer also has the correct background
        terminalView.wantsLayer = true
        terminalView.layer?.backgroundColor = backgroundColor.cgColor
        terminalView.layer?.isOpaque = true

        // Start shell process
        context.coordinator.startShell(in: terminalView)

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Update terminal if needed when state changes
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(terminalState: terminalState, onBell: onBell)
    }

    class Coordinator: NSObject {
        var terminalState: TerminalState
        let onBell: () -> Void
        weak var terminalView: LocalProcessTerminalView?
        private var cancellables = Set<AnyCancellable>()

        init(terminalState: TerminalState, onBell: @escaping () -> Void) {
            self.terminalState = terminalState
            self.onBell = onBell
            super.init()

            // Observe textToSend changes
            terminalState.$textToSend
                .sink { [weak self] text in
                    guard let self = self, !text.isEmpty else { return }
                    self.sendToTerminal(text)
                    // Clear after sending
                    DispatchQueue.main.async {
                        self.terminalState.textToSend = ""
                    }
                }
                .store(in: &cancellables)
        }

        func startShell(in terminalView: LocalProcessTerminalView) {
            // Store reference to terminal view
            self.terminalView = terminalView

            // Get user's default shell
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let homeDir = NSHomeDirectory()

            // Use system environment - no sandbox means full access
            var env = ProcessInfo.processInfo.environment
            env["TERM"] = "xterm-256color"
            env["LANG"] = "en_US.UTF-8"
            env["HOME"] = homeDir

            // MVP: Just set a good PATH with common locations
            env["PATH"] = "\(homeDir)/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

            // Set minimal prompt without $ symbol - just a space
            env["PS1"] = " "

            // Convert environment dictionary to array of strings
            let envArray = env.map { "\($0.key)=\($0.value)" }

            // Start shell as login shell
            terminalView.startProcess(
                executable: shell,
                args: ["-l"], // Login shell loads user configs
                environment: envArray,
                execName: "shell"
            )

            DispatchQueue.main.async {
                self.terminalState.isRunning = true
            }
        }

        func sendToTerminal(_ text: String) {
            guard let terminalView = self.terminalView else { return }
            terminalView.send(txt: text)
        }
    }
}

// MARK: - NSColor Extension

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            calibratedRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
