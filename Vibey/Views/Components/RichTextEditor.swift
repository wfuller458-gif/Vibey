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

        // Don't interfere while there's uncommitted input (e.g., dictation, input method)
        if textView.hasMarkedText() { return }

        // Compare archived data to detect external changes
        if let textStorage = textView.textStorage,
           let currentData = try? NSKeyedArchiver.archivedData(withRootObject: textStorage, requiringSecureCoding: false) {
            if currentData != content {
                loadContent(into: textView)
            }
        }
    }

    private func loadContent(into textView: NSTextView) {
        if content.isEmpty {
            textView.string = ""
            return
        }

        // Try NSKeyedUnarchiver first (new format with image support)
        // Use non-secure coding to allow NSTextAttachment, NSImage, etc.
        if let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: content) {
            unarchiver.requiresSecureCoding = false
            if let attrString = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString {
                textView.textStorage?.setAttributedString(attrString)
                return
            }
        }
        // Fall back to RTF (legacy format)
        if let attrString = NSAttributedString(rtf: content, documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attrString)
        }
        // Fall back to plain text
        else if let plainText = String(data: content, encoding: .utf8) {
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
            guard let textView = notification.object as? RichNSTextView,
                  let textStorage = textView.textStorage else { return }

            // Don't sync while there's uncommitted input (e.g., dictation, input method)
            if textView.hasMarkedText() { return }

            // Check for auto-list triggers ("- " or "1. " at start of line)
            checkAutoListTrigger(textView: textView, textStorage: textStorage)

            isUpdating = true
            // Use NSKeyedArchiver to preserve images (RTF doesn't embed images properly)
            if let archivedData = try? NSKeyedArchiver.archivedData(withRootObject: textStorage, requiringSecureCoding: false) {
                parent.content = archivedData
            }
            isUpdating = false
        }

        /// Check if user typed "- " or "1. " at start of line and convert to list
        private func checkAutoListTrigger(textView: RichNSTextView, textStorage: NSTextStorage) {
            let cursorPos = textView.selectedRange().location
            guard cursorPos >= 2 else { return }

            let nsString = textView.string as NSString
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: cursorPos, length: 0))

            // Get content from start of paragraph to cursor
            let startToCursor = cursorPos - paragraphRange.location

            // Check for "- " trigger (exactly 2 chars from line start)
            if startToCursor == 2 {
                let lineStart = nsString.substring(with: NSRange(location: paragraphRange.location, length: 2))
                if lineStart == "- " {
                    convertToBulletList(textView: textView, textStorage: textStorage, paragraphStart: paragraphRange.location)
                    return
                }
            }

            // Check for "1. " trigger (exactly 3 chars from line start)
            if startToCursor == 3 {
                let lineStart = nsString.substring(with: NSRange(location: paragraphRange.location, length: 3))
                if lineStart.range(of: "^\\d\\. $", options: .regularExpression) != nil {
                    convertToNumberedList(textView: textView, textStorage: textStorage, paragraphStart: paragraphRange.location, triggerLength: 3)
                    return
                }
            }

            // Check for "10. " or longer number triggers (4+ chars)
            if startToCursor >= 4 && startToCursor <= 6 {
                let lineStart = nsString.substring(with: NSRange(location: paragraphRange.location, length: startToCursor))
                if lineStart.range(of: "^\\d+\\. $", options: .regularExpression) != nil {
                    convertToNumberedList(textView: textView, textStorage: textStorage, paragraphStart: paragraphRange.location, triggerLength: startToCursor)
                    return
                }
            }
        }

        private func convertToBulletList(textView: RichNSTextView, textStorage: NSTextStorage, paragraphStart: Int) {
            // Delete "- " trigger text
            textStorage.beginEditing()
            textStorage.deleteCharacters(in: NSRange(location: paragraphStart, length: 2))
            textStorage.endEditing()

            // Position cursor at paragraph start
            textView.setSelectedRange(NSRange(location: paragraphStart, length: 0))

            // Defer applyBulletList to avoid re-entrancy issues with textDidChange
            DispatchQueue.main.async {
                textView.applyBulletList()
            }
        }

        private func convertToNumberedList(textView: RichNSTextView, textStorage: NSTextStorage, paragraphStart: Int, triggerLength: Int) {
            // Delete "1. " or similar trigger text
            textStorage.beginEditing()
            textStorage.deleteCharacters(in: NSRange(location: paragraphStart, length: triggerLength))
            textStorage.endEditing()

            // Position cursor at paragraph start
            textView.setSelectedRange(NSRange(location: paragraphStart, length: 0))

            // Defer applyNumberedList to avoid re-entrancy issues with textDidChange
            DispatchQueue.main.async {
                textView.applyNumberedList()
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? RichNSTextView else { return }
            updateSelectionState(textView)

            // Notify about selection change for floating toolbar
            let selectedRange = textView.selectedRange()
            let hasSelection = selectedRange.length > 0
            let selectionRect = hasSelection ? textView.getSelectionRectInWindow() : nil
            textView.onSelectionChanged?(hasSelection, selectionRect)
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
                    state.hasCheckbox = lineContent.hasPrefix("☐\t") || lineContent.hasPrefix("☑\t")
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
    // Track hovered line for showing menu icon
    var hoveredLineRange: NSRange? = nil
    // Track if mouse is directly over the icon button
    var isIconHovered: Bool = false

    // Left margin for hover menu icon (matches the SwiftUI padding being moved inside)
    static let hoverIconMargin: CGFloat = 32

    // Callback when text selection changes: (hasSelection, selectionRect in window coordinates)
    var onSelectionChanged: ((Bool, NSRect?) -> Void)? = nil

    // Callback when the three-dots icon is clicked: (lineRect in window coordinates)
    var onMoreIconClicked: ((NSRect) -> Void)? = nil

    // Callback when Escape is pressed (for dismissing floating toolbar)
    var onEscapePressed: (() -> Void)? = nil

    // Callback when an image is inserted (for toolbar updates)
    var onImageInserted: (() -> Void)? = nil

    // MARK: - Initialization

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupDragTypes()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragTypes()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragTypes()
    }

    private func setupDragTypes() {
        registerForDraggedTypes([.png, .tiff, .fileURL])
    }

    // MARK: - Image Insertion

    /// Insert an image at the current cursor position
    func insertImage(_ image: NSImage, maxWidth: CGFloat = 500) {
        guard let textStorage = textStorage else { return }

        // Scale image to fit
        let scaledImage = scaleImageToFit(image, maxWidth: maxWidth)

        let attachment = NSTextAttachment()
        attachment.image = scaledImage

        let attrString = NSAttributedString(attachment: attachment)

        textStorage.beginEditing()
        textStorage.replaceCharacters(in: selectedRange(), with: attrString)
        textStorage.endEditing()

        setSelectedRange(NSRange(location: selectedRange().location + 1, length: 0))
        didChangeText()
        onImageInserted?()
    }

    private func scaleImageToFit(_ image: NSImage, maxWidth: CGFloat) -> NSImage {
        guard image.size.width > maxWidth else { return image }
        let ratio = maxWidth / image.size.width
        let newSize = NSSize(width: maxWidth, height: image.size.height * ratio)
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        resized.unlockFocus()
        return resized
    }

    // MARK: - Drag & Drop for Images

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pb = sender.draggingPasteboard
        if pb.canReadObject(forClasses: [NSImage.self], options: nil) {
            return .copy
        }
        // Check for file URLs that are images
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "gif", "tiff", "bmp", "webp"].contains(ext) {
                    return .copy
                }
            }
        }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard

        // Try to read images directly
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            insertImage(image)
            return true
        }

        // Try to read file URLs and load images from them
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "gif", "tiff", "bmp", "webp"].contains(ext) {
                    if let image = NSImage(contentsOf: url) {
                        insertImage(image)
                        return true
                    }
                }
            }
        }

        return super.performDragOperation(sender)
    }

    // Override to add left-only margin for the hover icon area
    // This shifts text right without using textContainerInset (which affects both sides)
    override var textContainerOrigin: NSPoint {
        return NSPoint(x: RichNSTextView.hoverIconMargin, y: 0)
    }

    // Draw background - this gets called reliably for drawing in the margin
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        // Only draw hover icon if a line is hovered
        guard let hoveredRange = hoveredLineRange,
              let layoutManager = layoutManager,
              let textStorage = textStorage else {
            return
        }

        var lineRect: NSRect

        // Handle empty text or empty line at end
        if textStorage.length == 0 || hoveredRange.location >= textStorage.length {
            // Calculate default line height from typing attributes
            let defaultFont = (typingAttributes[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 16)
            let lineHeight = defaultFont.ascender - defaultFont.descender + defaultFont.leading + 8 // 8 is line spacing

            if textStorage.length == 0 {
                // First empty line
                lineRect = NSRect(x: 0, y: 0, width: bounds.width, height: lineHeight)
            } else {
                // Empty line at end - position below last line
                let lastGlyphIndex = layoutManager.numberOfGlyphs > 0 ? layoutManager.numberOfGlyphs - 1 : 0
                let lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIndex, effectiveRange: nil)
                lineRect = NSRect(x: 0, y: lastLineRect.maxY, width: bounds.width, height: lineHeight)
            }
        } else {
            // Normal case - get line rect from glyph
            let glyphRange = layoutManager.glyphRange(forCharacterRange: hoveredRange, actualCharacterRange: nil)
            guard glyphRange.location != NSNotFound && glyphRange.location < layoutManager.numberOfGlyphs else {
                return
            }

            lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            guard lineRect.height > 0 else {
                return
            }
        }

        // Button dimensions
        let buttonSize: CGFloat = 24
        let buttonX = (RichNSTextView.hoverIconMargin - buttonSize) / 2
        let buttonY = lineRect.origin.y + (lineRect.height - buttonSize) / 2
        let buttonRect = NSRect(x: buttonX, y: buttonY, width: buttonSize, height: buttonSize)

        // Only draw rounded rectangle background when icon is directly hovered
        if isIconHovered {
            let backgroundColor = NSColor(red: 45/255, green: 48/255, blue: 54/255, alpha: 1.0)
            let backgroundPath = NSBezierPath(roundedRect: buttonRect, xRadius: 6, yRadius: 6)
            backgroundColor.setFill()
            backgroundPath.fill()
        }

        // Always draw vertical dots icon (⋮) when line is hovered
        let iconString = "⋮"
        let iconFont = NSFont.systemFont(ofSize: 16, weight: .heavy)
        let iconColor = NSColor(red: 180/255, green: 183/255, blue: 190/255, alpha: 1.0)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: iconFont,
            .foregroundColor: iconColor
        ]

        let iconSize = iconString.size(withAttributes: attributes)
        let iconX = buttonX + (buttonSize - iconSize.width) / 2
        let iconY = buttonY + (buttonSize - iconSize.height) / 2

        iconString.draw(at: NSPoint(x: iconX, y: iconY), withAttributes: attributes)
    }

    // Get the selection rect in window coordinates for floating toolbar positioning
    func getSelectionRectInWindow() -> NSRect? {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return nil }

        let selectedRange = selectedRange()
        guard selectedRange.length > 0 else { return nil }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
        guard glyphRange.location != NSNotFound else { return nil }

        var selectionRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Offset for text container origin
        selectionRect.origin.x += textContainerOrigin.x
        selectionRect.origin.y += textContainerOrigin.y

        // Convert to window coordinates
        guard window != nil else { return selectionRect }
        return convert(selectionRect, to: nil)
    }

    // Get the line rect for the hovered line in window coordinates
    func getHoveredLineRectInWindow() -> NSRect? {
        guard let hoveredRange = hoveredLineRange,
              let layoutManager = layoutManager,
              let textStorage = textStorage else {
            return nil
        }

        var lineRect: NSRect

        // Handle empty text or empty line at end
        if textStorage.length == 0 || hoveredRange.location >= textStorage.length {
            let defaultFont = (typingAttributes[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 16)
            let lineHeight = defaultFont.ascender - defaultFont.descender + defaultFont.leading + 8

            if textStorage.length == 0 {
                lineRect = NSRect(x: 0, y: 0, width: bounds.width, height: lineHeight)
            } else {
                let lastGlyphIndex = layoutManager.numberOfGlyphs > 0 ? layoutManager.numberOfGlyphs - 1 : 0
                let lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIndex, effectiveRange: nil)
                lineRect = NSRect(x: 0, y: lastLineRect.maxY, width: bounds.width, height: lineHeight)
            }
        } else {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: hoveredRange, actualCharacterRange: nil)
            guard glyphRange.location != NSNotFound && glyphRange.location < layoutManager.numberOfGlyphs else {
                return nil
            }

            lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        }

        lineRect.origin.x += textContainerOrigin.x
        lineRect.origin.y += textContainerOrigin.y

        guard window != nil else { return lineRect }
        return convert(lineRect, to: nil)
    }

    // Helper to get the current icon button rect for hit testing
    private func getIconButtonRect() -> NSRect? {
        guard let hoveredRange = hoveredLineRange,
              let layoutManager = layoutManager,
              let textStorage = textStorage else {
            return nil
        }

        var lineRect: NSRect

        // Handle empty text or empty line at end
        if textStorage.length == 0 || hoveredRange.location >= textStorage.length {
            let defaultFont = (typingAttributes[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 16)
            let lineHeight = defaultFont.ascender - defaultFont.descender + defaultFont.leading + 8

            if textStorage.length == 0 {
                lineRect = NSRect(x: 0, y: 0, width: bounds.width, height: lineHeight)
            } else {
                let lastGlyphIndex = layoutManager.numberOfGlyphs > 0 ? layoutManager.numberOfGlyphs - 1 : 0
                let lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIndex, effectiveRange: nil)
                lineRect = NSRect(x: 0, y: lastLineRect.maxY, width: bounds.width, height: lineHeight)
            }
        } else {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: hoveredRange, actualCharacterRange: nil)
            guard glyphRange.location != NSNotFound && glyphRange.location < layoutManager.numberOfGlyphs else {
                return nil
            }

            lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            guard lineRect.height > 0 else {
                return nil
            }
        }

        let buttonSize: CGFloat = 24
        let buttonX = (RichNSTextView.hoverIconMargin - buttonSize) / 2
        let buttonY = lineRect.origin.y + (lineRect.height - buttonSize) / 2
        return NSRect(x: buttonX, y: buttonY, width: buttonSize, height: buttonSize)
    }

    // MARK: - Tracking Area Setup

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove existing tracking areas
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        // Add new tracking area for mouse movement - include the margin area
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    // Ensure we receive mouse events in the margin area (where the icon is)
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Convert point to local coordinates
        let localPoint = convert(point, from: superview)

        // If the point is within our bounds (including margin), claim the event
        if bounds.contains(localPoint) {
            return self
        }
        return super.hitTest(point)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)

        let point = convert(event.locationInWindow, from: nil)

        // Check if we have layout manager and text container
        guard let layoutManager = layoutManager,
              textContainer != nil,
              let textStorage = textStorage else {
            if hoveredLineRange != nil || isIconHovered {
                hoveredLineRange = nil
                isIconHovered = false
                setNeedsDisplay(bounds)
            }
            return
        }

        var needsRedraw = false
        var newHoveredRange: NSRange?

        if textStorage.length == 0 {
            // Empty text - treat as hovering first (empty) line
            // Use a sentinel range to indicate "first empty line"
            newHoveredRange = NSRange(location: 0, length: 0)
        } else {
            // Get character index at mouse position
            let charIndex = characterIndexForInsertion(at: point)
            let nsString = string as NSString

            // Check if mouse is below the last line of text
            let lastGlyphIndex = layoutManager.numberOfGlyphs > 0 ? layoutManager.numberOfGlyphs - 1 : 0
            let lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIndex, effectiveRange: nil)
            let lastLineBottom = lastLineRect.maxY

            if point.y > lastLineBottom && nsString.hasSuffix("\n") {
                // Mouse is below last text line and text ends with newline
                // This means we're on an empty line after the newline
                // Use a special range to indicate "empty line at end"
                newHoveredRange = NSRange(location: textStorage.length, length: 0)
            } else {
                // Normal case - get paragraph for character at mouse position
                let safeIndex = min(charIndex, textStorage.length > 0 ? textStorage.length - 1 : 0)
                newHoveredRange = nsString.paragraphRange(for: NSRange(location: safeIndex, length: 0))
            }
        }

        // Update hovered line
        if hoveredLineRange != newHoveredRange {
            hoveredLineRange = newHoveredRange
            needsRedraw = true
        }

        // Check if mouse is over the icon button
        let newIconHovered: Bool
        if let iconRect = getIconButtonRect() {
            newIconHovered = iconRect.contains(point)
        } else {
            newIconHovered = false
        }

        if isIconHovered != newIconHovered {
            isIconHovered = newIconHovered
            needsRedraw = true

            // Change cursor when hovering over icon
            if isIconHovered {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.iBeam.set()
            }
        }

        if needsRedraw {
            setNeedsDisplay(bounds)
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)

        if hoveredLineRange != nil || isIconHovered {
            hoveredLineRange = nil
            isIconHovered = false
            setNeedsDisplay(bounds)
        }
    }


    // Handle Enter, Backspace, and Escape for list continuation and toolbar dismiss
    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode

        // Escape key - dismiss floating toolbar
        if keyCode == 53 {
            onEscapePressed?()
            // Don't return - let default behavior also happen (deselect, etc.)
        }

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
        let hasCheckbox = lineContent.hasPrefix("☐\t") || lineContent.hasPrefix("☑\t")

        if !hasBullet && !hasNumber && !hasCheckbox {
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
        } else if hasCheckbox {
            newMarker = "\n☐\t"  // Always insert unchecked checkbox
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
        let hasCheckbox = lineContent.hasPrefix("☐\t") || lineContent.hasPrefix("☑\t")

        if !hasBullet && !hasNumber && !hasCheckbox {
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

    /// Get the length of a list marker (bullet, number, or checkbox)
    private func getListMarkerLength(_ lineContent: String) -> Int {
        if lineContent.hasPrefix("\u{2022}\t") || lineContent.hasPrefix("•\t") {
            return 2 // bullet + tab
        }
        if lineContent.hasPrefix("☐\t") || lineContent.hasPrefix("☑\t") {
            return 2 // checkbox + tab
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
        let nsString = string as NSString

        // Get the full range covering all paragraphs in selection
        let fullParagraphRange = nsString.paragraphRange(for: selectedRange)

        // Text color for markers (vibeyText)
        let textColor = NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0)
        let markerFont = NSFont.systemFont(ofSize: 16)

        // Get marker string for type
        func markerFor(_ listType: ListType, number: Int = 1) -> String {
            switch listType {
            case .bullet: return "\u{2022}\t"
            case .numbered: return "\(number).\t"
            case .checkbox: return "☐\t"
            }
        }

        // Check if we're on an empty line or at start of document
        let isEmpty = fullParagraphRange.length == 0 ||
            (fullParagraphRange.length == 1 && nsString.substring(with: fullParagraphRange) == "\n")

        if isEmpty || textStorage.length == 0 {
            // Empty line - just insert the marker directly
            let marker = markerFor(type)
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

        // Collect all paragraph ranges within the selection
        var paragraphRanges: [NSRange] = []
        var currentLocation = fullParagraphRange.location
        while currentLocation < fullParagraphRange.location + fullParagraphRange.length {
            let paraRange = nsString.paragraphRange(for: NSRange(location: currentLocation, length: 0))
            paragraphRanges.append(paraRange)
            currentLocation = paraRange.location + paraRange.length
            if currentLocation <= paraRange.location {
                break // Safety check to prevent infinite loop
            }
        }

        // Helper to check existing markers
        func checkLineMarkers(_ lineContent: String) -> (hasBullet: Bool, hasNumber: Bool, hasCheckbox: Bool, markerLen: Int) {
            let hasBullet = lineContent.hasPrefix("\u{2022}\t") || lineContent.hasPrefix("•\t")
            let hasNumber = lineContent.range(of: "^\\d+\\.\\t", options: .regularExpression) != nil
            let hasCheckbox = lineContent.hasPrefix("☐\t") || lineContent.hasPrefix("☑\t")

            var markerLen = 0
            if hasBullet { markerLen = 2 }
            else if hasCheckbox { markerLen = 2 }
            else if hasNumber {
                if let tabIndex = lineContent.firstIndex(of: "\t") {
                    markerLen = lineContent.distance(from: lineContent.startIndex, to: tabIndex) + 1
                }
            }
            return (hasBullet, hasNumber, hasCheckbox, markerLen)
        }

        textStorage.beginEditing()

        // Process paragraphs in reverse order to maintain correct positions
        var listNumber = paragraphRanges.count
        for paraRange in paragraphRanges.reversed() {
            let lineContent = nsString.substring(with: NSRange(location: paraRange.location, length: min(6, paraRange.length)))
            let (hasBullet, hasNumber, hasCheckbox, markerLen) = checkLineMarkers(lineContent)

            // Check if toggling off (same type already applied)
            let isSameType = (type == .bullet && hasBullet) ||
                             (type == .numbered && hasNumber) ||
                             (type == .checkbox && hasCheckbox)

            if isSameType {
                // Toggle off - remove the marker
                if markerLen > 0 {
                    // If it was a checked checkbox, also remove strikethrough
                    if hasCheckbox && lineContent.hasPrefix("☑\t") {
                        let contentStart = paraRange.location + markerLen
                        let contentRange = NSRange(location: contentStart, length: paraRange.length - markerLen)
                        if contentRange.length > 0 {
                            textStorage.removeAttribute(.strikethroughStyle, range: contentRange)
                        }
                    }
                    textStorage.deleteCharacters(in: NSRange(location: paraRange.location, length: markerLen))
                }
            } else {
                // Remove existing marker if switching type
                if hasBullet || hasNumber || hasCheckbox {
                    if markerLen > 0 {
                        // If switching from checked checkbox, remove strikethrough
                        if hasCheckbox && lineContent.hasPrefix("☑\t") {
                            let contentStart = paraRange.location + markerLen
                            let contentRange = NSRange(location: contentStart, length: paraRange.length - markerLen)
                            if contentRange.length > 0 {
                                textStorage.removeAttribute(.strikethroughStyle, range: contentRange)
                            }
                        }
                        textStorage.deleteCharacters(in: NSRange(location: paraRange.location, length: markerLen))
                    }
                }

                // Insert new marker (use correct number for numbered lists)
                let marker = markerFor(type, number: listNumber)
                let markerAttrs: [NSAttributedString.Key: Any] = [
                    .font: markerFont,
                    .foregroundColor: textColor
                ]
                let attrMarker = NSAttributedString(string: marker, attributes: markerAttrs)
                textStorage.insert(attrMarker, at: paraRange.location)
            }

            listNumber -= 1
        }

        textStorage.endEditing()
        didChangeText()
        notifyTypingAttributesChanged()
    }

    /// Toggle checkbox state when clicked
    func toggleCheckboxAt(_ location: Int) {
        guard let textStorage = textStorage else { return }

        let nsString = string as NSString
        let paragraphRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
        guard paragraphRange.length >= 2 else { return }

        let lineContent = nsString.substring(with: NSRange(location: paragraphRange.location, length: min(2, paragraphRange.length)))

        // Text color for markers
        let textColor = NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0)
        let markerFont = NSFont.systemFont(ofSize: 16)

        textStorage.beginEditing()

        if lineContent.hasPrefix("☐") {
            // Check it - replace with checked box and add strikethrough
            let markerAttrs: [NSAttributedString.Key: Any] = [
                .font: markerFont,
                .foregroundColor: textColor
            ]
            let checkedMarker = NSAttributedString(string: "☑", attributes: markerAttrs)
            textStorage.replaceCharacters(in: NSRange(location: paragraphRange.location, length: 1), with: checkedMarker)

            // Add strikethrough to rest of line (after marker + tab)
            let contentStart = paragraphRange.location + 2
            let contentLength = paragraphRange.length - 2
            if contentLength > 0 {
                // Remove trailing newline from strikethrough range
                var strikeRange = NSRange(location: contentStart, length: contentLength)
                if strikeRange.length > 0 {
                    let lastChar = nsString.substring(with: NSRange(location: strikeRange.location + strikeRange.length - 1, length: 1))
                    if lastChar == "\n" {
                        strikeRange.length -= 1
                    }
                }
                if strikeRange.length > 0 {
                    textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: strikeRange)
                }
            }
        } else if lineContent.hasPrefix("☑") {
            // Uncheck it - replace with unchecked box and remove strikethrough
            let markerAttrs: [NSAttributedString.Key: Any] = [
                .font: markerFont,
                .foregroundColor: textColor
            ]
            let uncheckedMarker = NSAttributedString(string: "☐", attributes: markerAttrs)
            textStorage.replaceCharacters(in: NSRange(location: paragraphRange.location, length: 1), with: uncheckedMarker)

            // Remove strikethrough from rest of line
            let contentStart = paragraphRange.location + 2
            let contentLength = paragraphRange.length - 2
            if contentLength > 0 {
                let contentRange = NSRange(location: contentStart, length: contentLength)
                textStorage.removeAttribute(.strikethroughStyle, range: contentRange)
            }
        }

        textStorage.endEditing()
        didChangeText()
        notifyTypingAttributesChanged()
    }

    /// Track if dictation is currently active
    var isDictating: Bool = false

    /// Callback when dictation state changes
    var onDictationStateChanged: ((Bool) -> Void)?

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

        // Trigger content sync after dictation ends
        // Use a brief delay to let macOS finalize the dictated text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.didChangeText()
        }
    }

    /// Toggle dictation on/off
    func toggleSystemDictation() {
        if isDictating {
            stopSystemDictation()
        } else {
            startSystemDictation()
        }
    }

    // Override to detect when dictation ends naturally
    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        // If we were dictating and text was inserted, dictation may have ended
        // We'll rely on the explicit stop for now
    }

    // Detect when dictation completes
    override func didChangeText() {
        super.didChangeText()
        // Check if dictation panel is still visible - if not, update state
        // This is a heuristic since there's no direct API
    }

    // Sync content when dictation finalizes (marked text is committed)
    override func unmarkText() {
        super.unmarkText()
        // Dictation has ended - reset state and sync content
        if isDictating {
            isDictating = false
            onDictationStateChanged?(false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.didChangeText()
        }
    }

    // MARK: - Paste (Images and Plain Text)

    /// Override paste to handle images and strip formatting from text
    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        // Check for image first
        if let image = NSImage(pasteboard: pasteboard) {
            insertImage(image)
            return
        }

        // Check for image file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "gif", "tiff", "bmp", "webp"].contains(ext) {
                    if let image = NSImage(contentsOf: url) {
                        insertImage(image)
                        return
                    }
                }
            }
        }

        // Fall back to plain text paste
        guard let plainText = pasteboard.string(forType: .string), !plainText.isEmpty else {
            return
        }

        // Build default attributes matching the app's text style
        let defaultFont = NSFont.systemFont(ofSize: 16)
        let defaultColor = NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0) // vibeyText
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8

        let attributes: [NSAttributedString.Key: Any] = [
            .font: defaultFont,
            .foregroundColor: defaultColor,
            .paragraphStyle: paragraphStyle
        ]

        let attributedText = NSAttributedString(string: plainText, attributes: attributes)

        // Insert at current selection (replacing any selected text)
        guard let textStorage = textStorage else { return }
        let selectedRange = selectedRange()

        textStorage.beginEditing()
        textStorage.replaceCharacters(in: selectedRange, with: attributedText)
        textStorage.endEditing()

        // Move cursor to end of pasted text
        let newCursorPos = selectedRange.location + plainText.count
        setSelectedRange(NSRange(location: newCursorPos, length: 0))

        didChangeText()
    }

    // Handle mouse clicks for checkbox toggling and three-dots icon
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let charIndex = characterIndexForInsertion(at: point)

        // Check if click is on the three-dots icon
        if let iconRect = getIconButtonRect(), iconRect.contains(point) {
            if let hoveredRange = hoveredLineRange, let lineRect = getHoveredLineRectInWindow() {
                // Select the entire line so formatting applies to it
                setSelectedRange(hoveredRange)
                onMoreIconClicked?(lineRect)
            }
            return
        }

        // Check if click is on a checkbox
        if charIndex < string.count {
            let nsString = string as NSString
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: charIndex, length: 0))

            if paragraphRange.length >= 2 {
                let lineStart = nsString.substring(with: NSRange(location: paragraphRange.location, length: 1))

                // Check if clicking on or near the checkbox character
                if lineStart == "☐" || lineStart == "☑" {
                    // Calculate if click is within the checkbox area (first ~20 pixels)
                    if let layoutManager = layoutManager, let textContainer = textContainer {
                        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: paragraphRange.location, length: 1), actualCharacterRange: nil)
                        let checkboxRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

                        // Expand hit area slightly for easier clicking
                        let hitArea = checkboxRect.insetBy(dx: -5, dy: -5)
                        if hitArea.contains(point) {
                            toggleCheckboxAt(paragraphRange.location)
                            return
                        }
                    }
                }
            }
        }

        super.mouseDown(with: event)
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