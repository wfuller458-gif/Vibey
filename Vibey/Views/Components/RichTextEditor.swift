//
//  RichTextEditor.swift
//  Vibey
//
//  NSViewRepresentable wrapping NSTextView for rich text editing
//  Supports spell check, grammar check, and rich text formatting
//

import SwiftUI
import AppKit

// MARK: - Selection State

/// Tracks the current text selection formatting state
struct TextSelectionState: Equatable {
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderline: Bool = false
    var isStrikethrough: Bool = false
    var fontSize: CGFloat = 16
    var textColor: NSColor = NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0)
    var hasBulletList: Bool = false
    var hasNumberedList: Bool = false
}

// MARK: - Rich Text Editor

struct RichTextEditor: NSViewRepresentable {
    @Binding var content: Data
    @Binding var selectionState: TextSelectionState
    var isComicSansMode: Bool = false

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = RichNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        // Enable spell checking and grammar
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Appearance
        textView.backgroundColor = NSColor(red: 18/255, green: 20/255, blue: 24/255, alpha: 1.0) // vibeyBackground
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

        // Default paragraph style for line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        textView.defaultParagraphStyle = paragraphStyle

        // Set default typing attributes - use system font (San Francisco) for body text
        // System font has proper bold/italic support
        let defaultFont = isComicSansMode
            ? NSFont(name: "Comic Sans MS", size: 16) ?? NSFont.systemFont(ofSize: 16)
            : NSFont.systemFont(ofSize: 16)

        textView.typingAttributes = [
            .font: defaultFont,
            .foregroundColor: NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]

        scrollView.documentView = textView
        context.coordinator.textView = textView

        // Load initial content
        loadContent(into: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? RichNSTextView else { return }

        // Update content only if it changed externally
        if context.coordinator.isUpdating { return }

        let currentRTF = textView.textStorage?.rtf(from: NSRange(location: 0, length: textView.textStorage?.length ?? 0), documentAttributes: [:])
        if currentRTF != content {
            loadContent(into: textView)
        }
    }

    private func loadContent(into textView: NSTextView) {
        if content.isEmpty {
            textView.string = ""
            return
        }

        if let attrString = NSAttributedString(rtf: content, documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attrString)
        } else if let plainText = String(data: content, encoding: .utf8) {
            // Use system font (San Francisco) for body text - has proper bold/italic support
            let font = isComicSansMode
                ? NSFont(name: "Comic Sans MS", size: 16) ?? NSFont.systemFont(ofSize: 16)
                : NSFont.systemFont(ofSize: 16)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0)
            ]
            let attrString = NSAttributedString(string: plainText, attributes: attributes)
            textView.textStorage?.setAttributedString(attrString)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        weak var textView: RichNSTextView?
        var isUpdating = false

        init(_ parent: RichTextEditor) {
            self.parent = parent
            super.init()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let textStorage = textView.textStorage else { return }

            isUpdating = true
            if let rtfData = textStorage.rtf(from: NSRange(location: 0, length: textStorage.length), documentAttributes: [:]) {
                parent.content = rtfData
            }
            isUpdating = false
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updateSelectionState(textView)
        }

        func updateSelectionState(_ textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            var state = TextSelectionState()

            if selectedRange.length > 0 {
                // Text is selected - show attributes of selection
                guard let textStorage = textView.textStorage,
                      selectedRange.location < textStorage.length else {
                    parent.selectionState = state
                    return
                }
                let attrs = textStorage.attributes(at: selectedRange.location, effectiveRange: nil)
                state = extractState(from: attrs)
            } else {
                // No selection (cursor only) - use typing attributes
                let attrs = textView.typingAttributes
                state = extractState(from: attrs)
            }

            // Check if current line has bullet or number
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                let nsString = textView.string as NSString
                let paragraphRange = nsString.paragraphRange(for: selectedRange)
                if paragraphRange.length > 0 {
                    let lineContent = nsString.substring(with: NSRange(location: paragraphRange.location, length: min(4, paragraphRange.length)))
                    state.hasBulletList = lineContent.hasPrefix("\u{2022}\t") || lineContent.hasPrefix("•\t")
                    state.hasNumberedList = lineContent.range(of: "^\\d+\\.\\t", options: .regularExpression) != nil
                }
            }

            parent.selectionState = state
        }

        private func extractState(from attrs: [NSAttributedString.Key: Any]) -> TextSelectionState {
            var state = TextSelectionState()

            if let font = attrs[.font] as? NSFont {
                state.fontSize = font.pointSize
                let traits = font.fontDescriptor.symbolicTraits
                state.isBold = traits.contains(.bold)
                state.isItalic = traits.contains(.italic)
            }

            if let underlineStyle = attrs[.underlineStyle] as? Int {
                state.isUnderline = underlineStyle != 0
            }

            if let strikethroughStyle = attrs[.strikethroughStyle] as? Int {
                state.isStrikethrough = strikethroughStyle != 0
            }

            if let color = attrs[.foregroundColor] as? NSColor {
                state.textColor = color
            }

            return state
        }
    }
}

// MARK: - Custom NSTextView

class RichNSTextView: NSTextView {
    // Handle Enter and Backspace for list continuation
    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode

        // Enter key (Return)
        if keyCode == 36 {
            if handleEnterKey() {
                return
            }
        }

        // Backspace key
        if keyCode == 51 {
            if handleBackspaceKey() {
                return
            }
        }

        // Let the responder chain handle other keys
        super.keyDown(with: event)
    }

    /// Handle Enter key - continue list if on a list line
    /// Returns true if handled, false to let default behavior proceed
    private func handleEnterKey() -> Bool {
        guard let textStorage = textStorage else { return false }

        let cursorPos = selectedRange().location
        let nsString = string as NSString

        // Get current paragraph/line
        let paragraphRange = nsString.paragraphRange(for: NSRange(location: cursorPos, length: 0))
        guard paragraphRange.length > 0 else { return false }

        let lineContent = nsString.substring(with: paragraphRange)
        let hasBullet = lineContent.hasPrefix("\u{2022}\t") || lineContent.hasPrefix("•\t")
        let hasNumber = lineContent.range(of: "^\\d+\\.\\t", options: .regularExpression) != nil

        if !hasBullet && !hasNumber {
            return false // Not a list line, use default behavior
        }

        // Check if line is empty (just the marker)
        let markerLength = getListMarkerLength(lineContent)
        let contentAfterMarker = String(lineContent.dropFirst(markerLength)).trimmingCharacters(in: .whitespacesAndNewlines)

        if contentAfterMarker.isEmpty {
            // Empty list item - remove the marker and don't add new line with marker
            textStorage.beginEditing()
            textStorage.deleteCharacters(in: paragraphRange)
            textStorage.endEditing()
            didChangeText()
            notifyTypingAttributesChanged()
            return true
        }

        // Text color for new marker
        let textColor = NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0)
        let markerFont = NSFont.systemFont(ofSize: 16)

        // Insert newline and new marker
        let newMarker: String
        if hasBullet {
            newMarker = "\n\u{2022}\t"
        } else {
            // Get current number and increment
            let currentNumber = extractListNumber(from: lineContent)
            newMarker = "\n\(currentNumber + 1).\t"
        }

        let markerAttrs: [NSAttributedString.Key: Any] = [
            .font: markerFont,
            .foregroundColor: textColor
        ]
        let attrMarker = NSAttributedString(string: newMarker, attributes: markerAttrs)

        textStorage.beginEditing()
        textStorage.replaceCharacters(in: selectedRange(), with: attrMarker)
        textStorage.endEditing()

        // Move cursor after new marker
        setSelectedRange(NSRange(location: cursorPos + newMarker.count, length: 0))
        didChangeText()
        notifyTypingAttributesChanged()
        return true
    }

    /// Handle Backspace key - remove marker if at start of empty list item
    /// Returns true if handled, false to let default behavior proceed
    private func handleBackspaceKey() -> Bool {
        guard let textStorage = textStorage else { return false }

        let cursorPos = selectedRange().location
        guard cursorPos > 0 else { return false }

        let nsString = string as NSString
        let paragraphRange = nsString.paragraphRange(for: NSRange(location: cursorPos, length: 0))
        guard paragraphRange.length > 0 else { return false }

        let lineContent = nsString.substring(with: paragraphRange)
        let hasBullet = lineContent.hasPrefix("\u{2022}\t") || lineContent.hasPrefix("•\t")
        let hasNumber = lineContent.range(of: "^\\d+\\.\\t", options: .regularExpression) != nil

        if !hasBullet && !hasNumber {
            return false // Not a list line
        }

        let markerLength = getListMarkerLength(lineContent)

        // Check if cursor is right after the marker (content is empty)
        let cursorPosInLine = cursorPos - paragraphRange.location
        if cursorPosInLine == markerLength {
            // Cursor is right after marker - remove the marker
            textStorage.beginEditing()
            textStorage.deleteCharacters(in: NSRange(location: paragraphRange.location, length: markerLength))
            textStorage.endEditing()

            // Position cursor at start of line
            setSelectedRange(NSRange(location: paragraphRange.location, length: 0))
            didChangeText()
            notifyTypingAttributesChanged()
            return true
        }

        return false // Let default backspace behavior happen
    }

    /// Get the length of a list marker (bullet or number)
    private func getListMarkerLength(_ lineContent: String) -> Int {
        if lineContent.hasPrefix("\u{2022}\t") || lineContent.hasPrefix("•\t") {
            return 2 // bullet + tab
        }
        // Find tab position for numbered list
        if let tabIndex = lineContent.firstIndex(of: "\t") {
            return lineContent.distance(from: lineContent.startIndex, to: tabIndex) + 1
        }
        return 0
    }

    /// Extract the number from a numbered list item
    private func extractListNumber(from lineContent: String) -> Int {
        let pattern = "^(\\d+)\\."
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: lineContent, range: NSRange(lineContent.startIndex..., in: lineContent)),
           let range = Range(match.range(at: 1), in: lineContent) {
            return Int(lineContent[range]) ?? 1
        }
        return 1
    }

    // Apply formatting at selection
    func applyBold() {
        applyBoldFormatting()
    }

    func applyItalic() {
        applyItalicFormatting()
    }

    /// Notify delegate that typing attributes changed so toolbar can update
    private func notifyTypingAttributesChanged() {
        NotificationCenter.default.post(name: NSTextView.didChangeSelectionNotification, object: self)
    }

    private func applyBoldFormatting() {
        guard let textStorage = textStorage else { return }
        let selectedRange = selectedRange()
        let fontManager = NSFontManager.shared

        if selectedRange.length == 0 {
            // Apply to typing attributes with toggle
            var attrs = typingAttributes
            if let font = attrs[.font] as? NSFont {
                let currentTraits = font.fontDescriptor.symbolicTraits
                let newFont: NSFont
                if currentTraits.contains(.bold) {
                    newFont = fontManager.convert(font, toNotHaveTrait: .boldFontMask)
                } else {
                    newFont = fontManager.convert(font, toHaveTrait: .boldFontMask)
                }
                attrs[.font] = newFont
                typingAttributes = attrs
                notifyTypingAttributesChanged()
            }
        } else {
            // Apply to selection
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
                if let font = value as? NSFont {
                    let currentTraits = font.fontDescriptor.symbolicTraits
                    let newFont: NSFont
                    if currentTraits.contains(.bold) {
                        newFont = fontManager.convert(font, toNotHaveTrait: .boldFontMask)
                    } else {
                        newFont = fontManager.convert(font, toHaveTrait: .boldFontMask)
                    }
                    textStorage.addAttribute(.font, value: newFont, range: range)
                }
            }
            textStorage.endEditing()
            didChangeText()
            notifyTypingAttributesChanged()
        }
    }

    private func applyItalicFormatting() {
        guard let textStorage = textStorage else { return }
        let selectedRange = selectedRange()
        let fontManager = NSFontManager.shared

        if selectedRange.length == 0 {
            // Apply to typing attributes with toggle
            var attrs = typingAttributes
            if let font = attrs[.font] as? NSFont {
                let currentTraits = font.fontDescriptor.symbolicTraits
                let newFont: NSFont
                if currentTraits.contains(.italic) {
                    newFont = fontManager.convert(font, toNotHaveTrait: .italicFontMask)
                } else {
                    newFont = fontManager.convert(font, toHaveTrait: .italicFontMask)
                }
                attrs[.font] = newFont
                typingAttributes = attrs
                notifyTypingAttributesChanged()
            }
        } else {
            // Apply to selection
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
                if let font = value as? NSFont {
                    let currentTraits = font.fontDescriptor.symbolicTraits
                    let newFont: NSFont
                    if currentTraits.contains(.italic) {
                        newFont = fontManager.convert(font, toNotHaveTrait: .italicFontMask)
                    } else {
                        newFont = fontManager.convert(font, toHaveTrait: .italicFontMask)
                    }
                    textStorage.addAttribute(.font, value: newFont, range: range)
                }
            }
            textStorage.endEditing()
            didChangeText()
            notifyTypingAttributesChanged()
        }
    }

    func applyUnderline() {
        applyAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, toggleValue: 0)
    }

    func applyStrikethrough() {
        applyAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, toggleValue: 0)
    }

    private func applyAttribute(_ key: NSAttributedString.Key, value: Any, toggleValue: Any) {
        guard let textStorage = textStorage else { return }
        let selectedRange = selectedRange()

        if selectedRange.length == 0 {
            // Apply to typing attributes
            var attrs = typingAttributes
            if let currentValue = attrs[key] as? Int, currentValue != 0 {
                attrs[key] = toggleValue
            } else {
                attrs[key] = value
            }
            typingAttributes = attrs
            notifyTypingAttributesChanged()
        } else {
            // Check current state
            let attrs = textStorage.attributes(at: selectedRange.location, effectiveRange: nil)
            let isCurrentlyApplied = (attrs[key] as? Int ?? 0) != 0

            textStorage.beginEditing()
            if isCurrentlyApplied {
                textStorage.addAttribute(key, value: toggleValue, range: selectedRange)
            } else {
                textStorage.addAttribute(key, value: value, range: selectedRange)
            }
            textStorage.endEditing()
            didChangeText()
            notifyTypingAttributesChanged()
        }
    }

    func applyTextColor(_ color: NSColor) {
        guard let textStorage = textStorage else { return }
        let selectedRange = selectedRange()

        if selectedRange.length == 0 {
            var attrs = typingAttributes
            attrs[.foregroundColor] = color
            typingAttributes = attrs
            notifyTypingAttributesChanged()
        } else {
            textStorage.beginEditing()
            textStorage.addAttribute(.foregroundColor, value: color, range: selectedRange)
            textStorage.endEditing()
            didChangeText()
            notifyTypingAttributesChanged()
        }
    }

    func applyHeading(_ level: Int) {
        guard let textStorage = textStorage else { return }

        let fontManager = NSFontManager.shared
        let selectedRange = selectedRange()
        let paragraphRange = (string as NSString).paragraphRange(for: selectedRange)

        let targetFontSize: CGFloat
        switch level {
        case 1: targetFontSize = 28
        case 2: targetFontSize = 22
        case 3: targetFontSize = 18
        default: targetFontSize = 16
        }

        // Check current state from typing attributes or paragraph
        var isAlreadyHeading = false
        if let currentFont = typingAttributes[.font] as? NSFont {
            isAlreadyHeading = abs(currentFont.pointSize - targetFontSize) < 1
        } else if paragraphRange.length > 0 {
            let attrs = textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
            if let font = attrs[.font] as? NSFont {
                isAlreadyHeading = abs(font.pointSize - targetFontSize) < 1
            }
        }

        // Determine the new font
        let newFont: NSFont
        if isAlreadyHeading {
            // Toggle off - revert to normal body text (system font, 16pt)
            newFont = NSFont.systemFont(ofSize: 16)
        } else {
            // Apply heading - use Lexend Bold for headers
            let lexendBold = NSFont(name: "Lexend-Bold", size: targetFontSize)
                ?? NSFont(name: "Lexend Bold", size: targetFontSize)
                ?? NSFont.boldSystemFont(ofSize: targetFontSize)
            newFont = lexendBold
        }

        // Always set typing attributes for new text
        var attrs = typingAttributes
        attrs[.font] = newFont
        typingAttributes = attrs

        // Also apply to existing paragraph content if any
        if paragraphRange.length > 0 {
            textStorage.beginEditing()
            textStorage.addAttribute(.font, value: newFont, range: paragraphRange)
            textStorage.endEditing()
            didChangeText()
        }

        notifyTypingAttributesChanged()
    }

    func applyBulletList() {
        applyList(numbered: false)
    }

    func applyNumberedList() {
        applyList(numbered: true)
    }

    private func applyList(numbered: Bool) {
        guard let textStorage = textStorage else { return }

        let selectedRange = selectedRange()
        let paragraphRange = (string as NSString).paragraphRange(for: selectedRange)

        // Text color for markers (vibeyText)
        let textColor = NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0)
        let markerFont = NSFont.systemFont(ofSize: 16)

        // Check if we're on an empty line or at start of document
        let isEmpty = paragraphRange.length == 0 ||
            (paragraphRange.length == 1 && (string as NSString).substring(with: paragraphRange) == "\n")

        if isEmpty || textStorage.length == 0 {
            // Empty line - just insert the marker directly
            let marker = numbered ? "1.\t" : "\u{2022}\t"
            let markerAttrs: [NSAttributedString.Key: Any] = [
                .font: markerFont,
                .foregroundColor: textColor
            ]
            let attrMarker = NSAttributedString(string: marker, attributes: markerAttrs)

            textStorage.beginEditing()
            textStorage.insert(attrMarker, at: selectedRange.location)
            textStorage.endEditing()

            // Move cursor after marker
            setSelectedRange(NSRange(location: selectedRange.location + marker.count, length: 0))
            didChangeText()
            notifyTypingAttributesChanged()
            return
        }

        // Check if already has bullet/number at start of paragraph
        let nsString = string as NSString
        let lineContent = nsString.substring(with: NSRange(location: paragraphRange.location, length: min(4, paragraphRange.length)))
        let hasBullet = lineContent.hasPrefix("\u{2022}\t") || lineContent.hasPrefix("•\t")
        let hasNumber = lineContent.range(of: "^\\d+\\.\\t", options: .regularExpression) != nil

        // Calculate marker length
        func getMarkerLength() -> Int {
            if hasBullet { return 2 }  // bullet + tab
            if hasNumber {
                // Find where the tab is to determine marker length (e.g., "1.\t" = 3, "10.\t" = 4)
                if let tabIndex = lineContent.firstIndex(of: "\t") {
                    return lineContent.distance(from: lineContent.startIndex, to: tabIndex) + 1
                }
            }
            return 0
        }

        textStorage.beginEditing()

        if (numbered && hasNumber) || (!numbered && hasBullet) {
            // Toggle off - remove the marker
            let markerLength = getMarkerLength()
            if markerLength > 0 {
                textStorage.deleteCharacters(in: NSRange(location: paragraphRange.location, length: markerLength))
            }
        } else {
            // Remove existing marker if switching type
            if hasBullet || hasNumber {
                let markerLength = getMarkerLength()
                if markerLength > 0 {
                    textStorage.deleteCharacters(in: NSRange(location: paragraphRange.location, length: markerLength))
                }
            }

            // Insert new marker
            let marker = numbered ? "1.\t" : "\u{2022}\t"
            let markerAttrs: [NSAttributedString.Key: Any] = [
                .font: markerFont,
                .foregroundColor: textColor
            ]
            let attrMarker = NSAttributedString(string: marker, attributes: markerAttrs)
            textStorage.insert(attrMarker, at: paragraphRange.location)
        }

        textStorage.endEditing()
        didChangeText()
        notifyTypingAttributesChanged()
    }
}

// MARK: - Preview

struct RichTextEditor_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }

    struct PreviewWrapper: View {
        @State private var content = Data()
        @State private var selectionState = TextSelectionState()

        var body: some View {
            RichTextEditor(content: $content, selectionState: $selectionState)
                .frame(width: 400, height: 300)
        }
    }
}