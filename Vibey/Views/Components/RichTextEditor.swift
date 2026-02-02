//
//  RichTextEditor.swift
//  Vibey
//
//  NSViewRepresentable wrapping NSTextView for rich text editing
//  Supports spell check, grammar check, and rich text formatting
//

import SwiftUI
import AppKit

// MARK: - Checkbox Text Attachment

class CheckboxAttachment: NSTextAttachment {
    var isChecked: Bool = false

    static let size: CGFloat = 18
    static let checkedColor = NSColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1.0) // Blue
    static let uncheckedBorderColor = NSColor(red: 100/255, green: 100/255, blue: 100/255, alpha: 1.0)
    static let checkmarkColor = NSColor.white

    convenience init(checked: Bool) {
        self.init()
        self.isChecked = checked
        self.image = Self.createImage(checked: checked)
    }

    static func createImage(checked: Bool) -> NSImage {
        let size = NSSize(width: Self.size, height: Self.size)
        let image = NSImage(size: size)

        image.lockFocus()

        let rect = NSRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)

        if checked {
            // Filled blue background
            checkedColor.setFill()
            path.fill()

            // White checkmark
            let checkPath = NSBezierPath()
            checkPath.lineWidth = 2
            checkPath.lineCapStyle = .round
            checkPath.lineJoinStyle = .round

            // Checkmark coordinates (scaled to our size)
            let startX = size.width * 0.25
            let midX = size.width * 0.45
            let endX = size.width * 0.75
            let startY = size.height * 0.5
            let midY = size.height * 0.3
            let endY = size.height * 0.7

            checkPath.move(to: NSPoint(x: startX, y: startY))
            checkPath.line(to: NSPoint(x: midX, y: midY))
            checkPath.line(to: NSPoint(x: endX, y: endY))

            checkmarkColor.setStroke()
            checkPath.stroke()
        } else {
            // Empty with border
            uncheckedBorderColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }

        image.unlockFocus()
        return image
    }

    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: NSRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> NSRect {
        // Center vertically with text
        let height = lineFrag.height
        let yOffset = (height - Self.size) / 2 - 2
        return NSRect(x: 0, y: yOffset, width: Self.size, height: Self.size)
    }
}

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
    var hasCheckbox: Bool = false
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

            // Check if current line has bullet, number, or checkbox
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                let nsString = textView.string as NSString
                let paragraphRange = nsString.paragraphRange(for: selectedRange)
                if paragraphRange.length > 0 {
                    let lineContent = nsString.substring(with: NSRange(location: paragraphRange.location, length: min(4, paragraphRange.length)))
                    state.hasBulletList = lineContent.hasPrefix("\u{2022}\t") || lineContent.hasPrefix("•\t")
                    state.hasNumberedList = lineContent.range(of: "^\\d+\\.\\t", options: .regularExpression) != nil

                    // Check for checkbox attachment at start of paragraph
                    state.hasCheckbox = false
                    if paragraphRange.location < textStorage.length {
                        if let attachment = textStorage.attribute(.attachment, at: paragraphRange.location, effectiveRange: nil) as? CheckboxAttachment {
                            state.hasCheckbox = true
                            _ = attachment // Silence unused warning
                        }
                    }
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

    override func resetCursorRects() {
        super.resetCursorRects()

        // Add pointer cursor rects for all checkbox attachments
        guard let textStorage = textStorage,
              let layoutManager = layoutManager,
              let textContainer = textContainer else { return }

        textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length), options: []) { value, range, _ in
            if value is CheckboxAttachment {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                var checkboxRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

                // Adjust for text container inset
                checkboxRect.origin.x += self.textContainerInset.width
                checkboxRect.origin.y += self.textContainerInset.height

                // Expand hit area
                checkboxRect = checkboxRect.insetBy(dx: -2, dy: -2)

                self.addCursorRect(checkboxRect, cursor: .pointingHand)
            }
        }
    }

    // Refresh cursor rects when text changes
    override func didChangeText() {
        super.didChangeText()
        window?.invalidateCursorRects(for: self)
    }

    // Handle mouse clicks for checkbox toggling
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if let (attachmentRange, attachment) = checkboxAttachmentAt(point) {
            toggleCheckbox(attachment, at: attachmentRange)
            return
        }

        super.mouseDown(with: event)
    }

    /// Find checkbox attachment at a point
    private func checkboxAttachmentAt(_ point: NSPoint) -> (NSRange, CheckboxAttachment)? {
        guard let textStorage = textStorage,
              let layoutManager = layoutManager,
              let textContainer = textContainer else { return nil }

        // Adjust point for text container inset
        let adjustedPoint = NSPoint(
            x: point.x - textContainerInset.width,
            y: point.y - textContainerInset.height
        )

        let charIndex = layoutManager.characterIndex(for: adjustedPoint, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        guard charIndex < textStorage.length else { return nil }

        // Check if there's a checkbox attachment at this position
        var effectiveRange = NSRange()
        if let attachment = textStorage.attribute(.attachment, at: charIndex, effectiveRange: &effectiveRange) as? CheckboxAttachment {
            // Verify click is within the attachment bounds
            let glyphRange = layoutManager.glyphRange(forCharacterRange: effectiveRange, actualCharacterRange: nil)
            var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            rect = rect.insetBy(dx: -5, dy: -5)

            if rect.contains(adjustedPoint) {
                return (effectiveRange, attachment)
            }
        }

        return nil
    }

    /// Toggle a checkbox attachment
    private func toggleCheckbox(_ attachment: CheckboxAttachment, at range: NSRange) {
        guard let textStorage = textStorage else { return }

        let newChecked = !attachment.isChecked
        let newAttachment = CheckboxAttachment(checked: newChecked)

        // Get paragraph range for strikethrough
        let nsString = string as NSString
        let paragraphRange = nsString.paragraphRange(for: range)

        textStorage.beginEditing()

        // Replace attachment
        let attachmentString = NSMutableAttributedString(attachment: newAttachment)
        // Preserve font color for the attachment character
        let textColor = NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0)
        attachmentString.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: 1))
        textStorage.replaceCharacters(in: range, with: attachmentString)

        // Apply or remove strikethrough to content after checkbox (skip attachment + space)
        let contentStart = paragraphRange.location + 2  // attachment + space
        var contentLength = paragraphRange.length - 2
        if contentLength > 0 {
            // Don't include trailing newline
            let endIndex = contentStart + contentLength - 1
            if endIndex < nsString.length && nsString.substring(with: NSRange(location: endIndex, length: 1)) == "\n" {
                contentLength -= 1
            }
        }

        if contentLength > 0 {
            let contentRange = NSRange(location: contentStart, length: contentLength)
            if newChecked {
                textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
            } else {
                textStorage.removeAttribute(.strikethroughStyle, range: contentRange)
            }
        }

        textStorage.endEditing()
        didChangeText()
        notifyTypingAttributesChanged()
    }

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

        // Check for checkbox attachment
        var hasCheckbox = false
        if paragraphRange.location < textStorage.length {
            hasCheckbox = textStorage.attribute(.attachment, at: paragraphRange.location, effectiveRange: nil) is CheckboxAttachment
        }

        if !hasBullet && !hasNumber && !hasCheckbox {
            return false // Not a list line, use default behavior
        }

        // Check if line is empty (just the marker)
        let markerLength = getListMarkerLength(lineContent, hasCheckboxAttachment: hasCheckbox)
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

        textStorage.beginEditing()

        if hasCheckbox {
            // Insert newline, then checkbox attachment, then space
            let newlineAttr = NSAttributedString(string: "\n", attributes: [.font: markerFont, .foregroundColor: textColor])
            textStorage.replaceCharacters(in: selectedRange(), with: newlineAttr)

            let insertPos = cursorPos + 1
            let checkboxAttachment = CheckboxAttachment(checked: false)
            let attachmentString = NSMutableAttributedString(attachment: checkboxAttachment)
            attachmentString.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: 1))
            textStorage.insert(attachmentString, at: insertPos)

            let spaceAttr = NSAttributedString(string: " ", attributes: [.font: markerFont, .foregroundColor: textColor])
            textStorage.insert(spaceAttr, at: insertPos + 1)

            textStorage.endEditing()
            setSelectedRange(NSRange(location: insertPos + 2, length: 0))
        } else {
            // Insert newline and text marker
            let newMarker: String
            if hasBullet {
                newMarker = "\n\u{2022}\t"
            } else {
                let currentNumber = extractListNumber(from: lineContent)
                newMarker = "\n\(currentNumber + 1).\t"
            }

            let markerAttrs: [NSAttributedString.Key: Any] = [
                .font: markerFont,
                .foregroundColor: textColor
            ]
            let attrMarker = NSAttributedString(string: newMarker, attributes: markerAttrs)
            textStorage.replaceCharacters(in: selectedRange(), with: attrMarker)
            textStorage.endEditing()
            setSelectedRange(NSRange(location: cursorPos + newMarker.count, length: 0))
        }

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

        // Check for checkbox attachment
        var hasCheckbox = false
        if paragraphRange.location < textStorage.length {
            hasCheckbox = textStorage.attribute(.attachment, at: paragraphRange.location, effectiveRange: nil) is CheckboxAttachment
        }

        if !hasBullet && !hasNumber && !hasCheckbox {
            return false // Not a list line
        }

        let markerLength = getListMarkerLength(lineContent, hasCheckboxAttachment: hasCheckbox)

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

    /// Get the length of a list marker (bullet, number, or checkbox)
    private func getListMarkerLength(_ lineContent: String, hasCheckboxAttachment: Bool = false) -> Int {
        if lineContent.hasPrefix("\u{2022}\t") || lineContent.hasPrefix("•\t") {
            return 2 // bullet + tab
        }
        if hasCheckboxAttachment {
            return 2 // attachment char + space
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
        applyList(type: .bullet)
    }

    func applyNumberedList() {
        applyList(type: .numbered)
    }

    func applyCheckboxList() {
        applyList(type: .checkbox)
    }

    private enum ListType {
        case bullet
        case numbered
        case checkbox
    }

    private func applyList(type: ListType) {
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
            textStorage.beginEditing()

            if type == .checkbox {
                // Insert checkbox attachment + space
                let checkboxAttachment = CheckboxAttachment(checked: false)
                let attachmentString = NSMutableAttributedString(attachment: checkboxAttachment)
                attachmentString.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: 1))
                textStorage.insert(attachmentString, at: selectedRange.location)

                let spaceAttr = NSAttributedString(string: " ", attributes: [.font: markerFont, .foregroundColor: textColor])
                textStorage.insert(spaceAttr, at: selectedRange.location + 1)

                textStorage.endEditing()
                setSelectedRange(NSRange(location: selectedRange.location + 2, length: 0))
            } else {
                // Insert text marker
                let marker = type == .bullet ? "\u{2022}\t" : "1.\t"
                let markerAttrs: [NSAttributedString.Key: Any] = [
                    .font: markerFont,
                    .foregroundColor: textColor
                ]
                let attrMarker = NSAttributedString(string: marker, attributes: markerAttrs)
                textStorage.insert(attrMarker, at: selectedRange.location)
                textStorage.endEditing()
                setSelectedRange(NSRange(location: selectedRange.location + marker.count, length: 0))
            }

            didChangeText()
            notifyTypingAttributesChanged()
            return
        }

        // Check if already has bullet/number/checkbox at start of paragraph
        let nsString = string as NSString
        let lineContent = nsString.substring(with: NSRange(location: paragraphRange.location, length: min(4, paragraphRange.length)))
        let hasBullet = lineContent.hasPrefix("\u{2022}\t") || lineContent.hasPrefix("•\t")
        let hasNumber = lineContent.range(of: "^\\d+\\.\\t", options: .regularExpression) != nil

        // Check for checkbox attachment
        var hasCheckboxAttachment = false
        var isChecked = false
        if paragraphRange.location < textStorage.length {
            if let attachment = textStorage.attribute(.attachment, at: paragraphRange.location, effectiveRange: nil) as? CheckboxAttachment {
                hasCheckboxAttachment = true
                isChecked = attachment.isChecked
            }
        }

        // Calculate marker length
        func getMarkerLen() -> Int {
            if hasBullet { return 2 }  // bullet + tab
            if hasCheckboxAttachment { return 2 }  // attachment + space
            if hasNumber {
                if let tabIndex = lineContent.firstIndex(of: "\t") {
                    return lineContent.distance(from: lineContent.startIndex, to: tabIndex) + 1
                }
            }
            return 0
        }

        textStorage.beginEditing()

        // Check if toggling off (same type already applied)
        let isSameType = (type == .bullet && hasBullet) ||
                         (type == .numbered && hasNumber) ||
                         (type == .checkbox && hasCheckboxAttachment)

        if isSameType {
            // Toggle off - remove the marker
            let markerLength = getMarkerLen()
            if markerLength > 0 {
                // If it was a checked checkbox, also remove strikethrough from the line
                if hasCheckboxAttachment && isChecked {
                    let contentStart = paragraphRange.location + markerLength
                    let contentRange = NSRange(location: contentStart, length: paragraphRange.length - markerLength)
                    if contentRange.length > 0 {
                        textStorage.removeAttribute(.strikethroughStyle, range: contentRange)
                    }
                }
                textStorage.deleteCharacters(in: NSRange(location: paragraphRange.location, length: markerLength))
            }
        } else {
            // Remove existing marker if switching type
            if hasBullet || hasNumber || hasCheckboxAttachment {
                let markerLength = getMarkerLen()
                if markerLength > 0 {
                    // If switching from checked checkbox, remove strikethrough
                    if hasCheckboxAttachment && isChecked {
                        let contentStart = paragraphRange.location + markerLength
                        let contentRange = NSRange(location: contentStart, length: paragraphRange.length - markerLength)
                        if contentRange.length > 0 {
                            textStorage.removeAttribute(.strikethroughStyle, range: contentRange)
                        }
                    }
                    textStorage.deleteCharacters(in: NSRange(location: paragraphRange.location, length: markerLength))
                }
            }

            // Insert new marker
            if type == .checkbox {
                let checkboxAttachment = CheckboxAttachment(checked: false)
                let attachmentString = NSMutableAttributedString(attachment: checkboxAttachment)
                attachmentString.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: 1))
                textStorage.insert(attachmentString, at: paragraphRange.location)

                let spaceAttr = NSAttributedString(string: " ", attributes: [.font: markerFont, .foregroundColor: textColor])
                textStorage.insert(spaceAttr, at: paragraphRange.location + 1)
            } else {
                let marker = type == .bullet ? "\u{2022}\t" : "1.\t"
                let markerAttrs: [NSAttributedString.Key: Any] = [
                    .font: markerFont,
                    .foregroundColor: textColor
                ]
                let attrMarker = NSAttributedString(string: marker, attributes: markerAttrs)
                textStorage.insert(attrMarker, at: paragraphRange.location)
            }
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