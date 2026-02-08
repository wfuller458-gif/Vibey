//
//  TerminalMessageEditor.swift
//  Vibey
//
//  WhatsApp-style message input below terminal for composing prompts
//  Enter sends, Shift+Enter inserts newline
//

import SwiftUI
import AppKit
import CoreGraphics

// MARK: - MessageNSTextView

/// Custom NSTextView that handles Enter key for sending and Shift+Enter for newlines
class MessageNSTextView: NSTextView {
    var onSend: (() -> Void)?

    /// Track if dictation is currently active
    var isDictating: Bool = false

    /// Callback when dictation state changes
    var onDictationStateChanged: ((Bool) -> Void)?

    override func keyDown(with event: NSEvent) {
        // Enter key (keyCode 36) without Shift modifier
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
            onSend?()
            return
        }
        // Shift+Enter or other keys - default behavior
        super.keyDown(with: event)
    }

    // MARK: - Dictation Support

    /// Start the built-in macOS dictation
    @objc func startSystemDictation() {
        // Make sure this text view is first responder
        window?.makeFirstResponder(self)
        // Trigger system dictation using the Edit menu action
        let dictationSelector = NSSelectorFromString("startDictation:")
        NSApp.sendAction(dictationSelector, to: nil, from: self)
        isDictating = true
        onDictationStateChanged?(true)
    }

    /// Stop the built-in macOS dictation
    @objc func stopSystemDictation() {
        // Post Escape key event to the system to dismiss dictation
        let escapeKeyCode: UInt16 = 53

        // Key down
        if let escapeDown = CGEvent(keyboardEventSource: nil, virtualKey: escapeKeyCode, keyDown: true) {
            escapeDown.post(tap: .cghidEventTap)
        }
        // Key up
        if let escapeUp = CGEvent(keyboardEventSource: nil, virtualKey: escapeKeyCode, keyDown: false) {
            escapeUp.post(tap: .cghidEventTap)
        }

        isDictating = false
        onDictationStateChanged?(false)
    }

    /// Toggle dictation on/off
    func toggleSystemDictation() {
        if isDictating {
            stopSystemDictation()
        } else {
            startSystemDictation()
        }
    }
}

// MARK: - DictationController

/// Controller to manage dictation from SwiftUI
class DictationController: ObservableObject {
    weak var textView: MessageNSTextView?
    private var globalMonitor: Any?

    func toggleDictation() {
        guard let textView = textView else { return }

        if textView.isDictating {
            stopDictation()
        } else {
            startDictation()
        }
    }

    private func startDictation() {
        textView?.startSystemDictation()
        installMonitors()
    }

    private func stopDictation() {
        removeMonitors()
        textView?.stopSystemDictation()
    }

    private func installMonitors() {
        // Global monitor catches clicks when dictation UI has focus (outside our app)
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.stopDictation()
                }
            }
        }
    }

    private func removeMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    deinit {
        removeMonitors()
    }
}

// MARK: - MessageInputField

/// NSViewRepresentable wrapping MessageNSTextView for SwiftUI
struct MessageInputField: NSViewRepresentable {
    @Binding var text: String
    var onSend: () -> Void
    var onHeightChange: ((CGFloat) -> Void)?
    var onDictationStateChanged: ((Bool) -> Void)?
    var isComicSansMode: Bool
    var dictationController: DictationController?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = MessageNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Appearance
        textView.backgroundColor = .clear
        textView.insertionPointColor = NSColor.white
        textView.textColor = NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0) // vibeyText

        // Text container setup
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 0, height: 4)

        // Font
        let font: NSFont
        if isComicSansMode {
            font = NSFont(name: "Comic Sans MS", size: 14) ?? NSFont.systemFont(ofSize: 14)
        } else {
            font = NSFont(name: "Atkinson Hyperlegible", size: 14) ?? NSFont.systemFont(ofSize: 14)
        }

        textView.font = font
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0)
        ]

        // Callbacks
        textView.onSend = onSend
        textView.onDictationStateChanged = onDictationStateChanged

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        // Connect dictation controller to the text view
        dictationController?.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MessageNSTextView else { return }

        // Don't update while coordinator is processing changes (matches RichTextEditor)
        if context.coordinator.isUpdating { return }

        // Update text only if changed externally
        if textView.string != text {
            textView.string = text
            context.coordinator.updateHeight()
        }

        // Update callbacks
        textView.onSend = onSend
        textView.onDictationStateChanged = onDictationStateChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MessageInputField
        weak var textView: MessageNSTextView?
        weak var scrollView: NSScrollView?
        var isUpdating = false

        init(_ parent: MessageInputField) {
            self.parent = parent
            super.init()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? MessageNSTextView else { return }

            isUpdating = true
            parent.text = textView.string
            isUpdating = false

            // Update height as user types
            updateHeight()
        }

        func updateHeight() {
            guard let textView = textView,
                  let scrollView = scrollView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            // Force layout
            layoutManager.ensureLayout(for: textContainer)

            // Calculate content height
            let usedRect = layoutManager.usedRect(for: textContainer)
            let contentHeight = usedRect.height + textView.textContainerInset.height * 2

            // Clamp to 1-6 lines (approximately 22pt per line)
            let lineHeight: CGFloat = 22
            let minHeight = lineHeight
            let maxHeight = lineHeight * 6
            let clampedHeight = min(max(contentHeight, minHeight), maxHeight)

            parent.onHeightChange?(clampedHeight)
        }
    }
}

// MARK: - TerminalMessageEditor

struct TerminalMessageEditor: View {
    @ObservedObject var terminalState: TerminalState
    let isComicSansMode: Bool

    @State private var messageText: String = ""
    @State private var textFieldHeight: CGFloat = 22
    @State private var isDictating: Bool = false
    @StateObject private var dictationController = DictationController()

    var body: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(Color.vibeyCardBorder)
                .frame(height: 1)

            // Content
            HStack(alignment: .bottom, spacing: 12) {
                // Text field
                MessageInputField(
                    text: $messageText,
                    onSend: sendMessage,
                    onHeightChange: { height in
                        textFieldHeight = height
                    },
                    onDictationStateChanged: { dictating in
                        isDictating = dictating
                    },
                    isComicSansMode: isComicSansMode,
                    dictationController: dictationController
                )
                .frame(height: textFieldHeight)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "2A2D33"))
                .cornerRadius(8)

                // Buttons
                HStack(spacing: 8) {
                    // Mic button
                    Button(action: toggleDictation) {
                        ZStack {
                            Circle()
                                .fill(isDictating ? Color.red : Color.vibeyBlue)
                                .frame(width: 32, height: 32)

                            Image(systemName: isDictating ? "stop.fill" : "mic.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(isDictating ? "Stop dictation" : "Start dictation")

                    // Send button
                    Button(action: sendMessage) {
                        HStack(spacing: 4) {
                            Text("Send")
                                .font(.atkinsonRegular(size: 13, comicSans: isComicSansMode))

                            Image(systemName: "return")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.vibeyBlue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                    .help("Send message (Enter)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(hex: "1C1E22"))
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if text.contains("\n") {
            // Multi-line: use bracketed paste mode
            terminalState.sendText("\u{1b}[200~\(text)\u{1b}[201~")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                terminalState.sendText("\r")
            }
        } else {
            // Single line: just send with carriage return
            terminalState.sendText(text + "\r")
        }

        messageText = ""
    }

    private func toggleDictation() {
        dictationController.toggleDictation()
    }
}

// MARK: - Preview

#Preview {
    TerminalMessageEditor(
        terminalState: TerminalState(),
        isComicSansMode: false
    )
    .frame(width: 600)
}
