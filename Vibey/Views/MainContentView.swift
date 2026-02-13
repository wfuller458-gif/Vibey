//
//  MainContentView.swift
//  Vibey
//
//  Main app interface matching Figma design
//  3-panel layout: Sidebar | Page Editor | Terminal
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.isComicSansMode) var isComicSansMode
    @State private var selectedPageID: UUID? = nil
    @State private var sidebarWidth: CGFloat = 220
    @State private var terminalWidth: CGFloat = 400

    var body: some View {
        Group {
            if appState.projects.isEmpty {
                // Show projects list with empty state
                ProjectsListView()
                    .environmentObject(appState)
            } else {
                // Normal 3-panel layout
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Left Sidebar (resizable)
                        LeftSidebar(
                            selectedPageID: $selectedPageID,
                            onAddPage: {
                                guard let project = appState.currentProject else { return }
                                let newPage = Page(projectID: project.id)
                                appState.addPage(newPage, to: project.id)
                                selectedPageID = newPage.id
                            },
                            onSelectPage: { pageID in
                                selectedPageID = pageID
                            },
                            onDeletePage: { pageID in
                                guard let projectID = appState.currentProject?.id else { return }
                                appState.deletePage(pageID, from: projectID)

                                // Update selection
                                if selectedPageID == pageID {
                                    // Get updated project after deletion
                                    selectedPageID = appState.currentProject?.pages.first?.id
                                }
                            }
                        )
                        .frame(width: sidebarWidth)

                        // Draggable divider for sidebar
                        DraggableDivider(width: $sidebarWidth, minWidth: 220, maxWidth: 280)

                        // Middle Panel - Page Editor (flexible)
                        Group {
                            if let pageID = selectedPageID,
                               let projectIndex = appState.projects.firstIndex(where: { $0.id == appState.currentProject?.id }),
                               let pageIndex = appState.projects[projectIndex].pages.firstIndex(where: { $0.id == pageID }) {
                                PageEditorPanel(
                                    page: $appState.projects[projectIndex].pages[pageIndex],
                                    onSendContext: { page in
                                        sendPageContext(page)
                                    }
                                )
                                .id("\(pageID)-\(isComicSansMode)") // Force view to refresh when switching pages or comic sans mode changes
                            } else {
                                // Empty state when no page is selected
                                VStack(spacing: 16) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 48))
                                        .foregroundColor(.vibeyText.opacity(0.3))

                                    Text("No Page Selected")
                                        .font(.atkinsonRegular(size: 16, comicSans: isComicSansMode))
                                        .foregroundColor(.vibeyText.opacity(0.7))

                                    Text("Create a new page to get started")
                                        .font(.atkinsonRegular(size: 14, comicSans: isComicSansMode))
                                        .foregroundColor(.vibeyText.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.vibeyBackground)
                            }
                        }
                        .frame(width: geometry.size.width - sidebarWidth - terminalWidth - 48) // 48 for dividers (24px each)
                        .zIndex(1) // Ensure floating toolbar renders above terminal panel

                        // Draggable divider for terminal
                        DraggableDivider(width: $terminalWidth, minWidth: 300, maxWidth: 800, reverseDirection: true)

                        // Right Panel - Terminal (resizable)
                        TerminalPanel()
                            .frame(width: terminalWidth)
                    }
                    .background(Color.vibeyBackground)
                }
            }
        }
    }

    private func sendPageContext(_ page: Page) {
        guard let currentProject = appState.currentProject else { return }

        // Track usage on page context send
        appState.trackUsage()

        // Build the page context with line breaks preserved
        var contextText = ""

        if !page.title.isEmpty {
            contextText += "# \(page.title)\n\n"
        }

        // Get plain text from rich text content (preserves line breaks)
        let plainContent = page.plainText
        if !plainContent.isEmpty {
            contextText += plainContent
        }

        // Extract images to temp files
        let imagePaths = page.extractImagesForTerminal()
        if !imagePaths.isEmpty {
            contextText += "\n\n## Images\n"
            for path in imagePaths {
                contextText += "- \(path)\n"
            }
        }

        // Capture terminalState reference for the closure
        let terminalState = currentProject.terminalState

        // Send text directly (no bracketed paste - Claude handles multi-line input)
        terminalState.sendText(contextText)

        // Use longer delay for larger content - Claude Code needs time to process
        let delay = contextText.count > 500 ? 0.3 : 0.05

        // After delay, send Enter to submit to Claude
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            terminalState.sendText("\r")
        }

        // Update page status to shared
        appState.updatePageStatus(page.id, status: .shared, sharedAt: Date())
    }
}

// MARK: - Left Sidebar
struct LeftSidebar: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.showingProjectsList) var showingProjectsList
    @Environment(\.isComicSansMode) var isComicSansMode
    @Binding var selectedPageID: UUID?
    let onAddPage: () -> Void
    let onSelectPage: (UUID) -> Void
    let onDeletePage: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Logo (keep brand consistent even in Comic Sans mode)
            HStack {
                Image("VibeyLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 29.538)

                Spacer()
            }
            .padding(16)
            .padding(.bottom, 24)

            // Project name
            HStack(spacing: 8) {
                Text(appState.currentProject?.name ?? "No Project")
                    .font(.lexendBold(size: 16, comicSans: isComicSansMode))
                    .foregroundColor(.white)
                    .kerning(1.12)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

            // PAGES section (scrollable)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 8) {
                    Text("PAGES")
                        .font(.lexendLight(size: 12, comicSans: isComicSansMode))
                        .foregroundColor(.white.opacity(0.6))
                        .kerning(0.84)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    // Read pages directly from projects array to stay in sync with edits
                    if let projectIndex = appState.projects.firstIndex(where: { $0.id == appState.currentProject?.id }) {
                        ForEach(appState.projects[projectIndex].pages) { page in
                            SidebarButton(
                                title: page.title.isEmpty ? "New Page" : page.title,
                                icon: nil,
                                isSelected: selectedPageID == page.id,
                                showClose: true,
                                statusIcon: page.status,
                                action: { onSelectPage(page.id) },
                                onClose: { onDeletePage(page.id) }
                            )
                        }
                    }

                    SidebarButton(
                        title: "Add Page",
                        icon: "plus",
                        isSelected: false,
                        showClose: false,
                        action: onAddPage
                    )
                }
                .padding(.horizontal, 8)
            }

            // Trial banner and All Projects button at bottom (pinned)
            VStack(spacing: 12) {
                // Trial banner (only shows if on trial)
                TrialBannerView()
                    .environmentObject(appState)

                SidebarButton(
                    title: "All Projects",
                    icon: "Back",
                    isSelected: false,
                    showClose: false,
                    action: {
                        showingProjectsList.wrappedValue = true
                    }
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 16)
            .background(Color(hex: "242529"))
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "242529"))
    }
}

// MARK: - Sidebar Button
struct SidebarButton: View {
    @Environment(\.isComicSansMode) var isComicSansMode
    let title: String
    let icon: String?
    let isSelected: Bool
    let showClose: Bool
    var statusIcon: PageStatus? = nil
    let action: () -> Void
    var onClose: (() -> Void)? = nil

    @State private var showingDeleteConfirmation = false
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    // Check if it's a custom asset (starts with uppercase) or SF Symbol
                    if icon.first?.isUppercase == true {
                        Image(icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                    }
                } else if let status = statusIcon {
                    Image(statusImageName(for: status))
                        .resizable()
                        .frame(width: 24, height: 24)
                }

                Text(title)
                    .font(.atkinsonRegular(size: 16, comicSans: isComicSansMode))
                    .foregroundColor(.white)
                    .kerning(1.12)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                if showClose && isHovered {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image("Close")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color(hex: "484848") : (isHovered ? Color(hex: "484848").opacity(0.5) : Color.clear))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .confirmationDialog("Delete Page", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onClose?()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this page?")
        }
    }

    private func statusImageName(for status: PageStatus) -> String {
        switch status {
        case .notShared:
            return "PageStatusDefault"
        case .shared:
            return "PageStatusShared"
        case .contextLost:
            return "PageStatusRemoved"
        }
    }
}

// MARK: - Page Editor Panel
struct PageEditorPanel: View {
    @Environment(\.isComicSansMode) var isComicSansMode
    @Binding var page: Page
    let onSendContext: (Page) -> Void
    @FocusState private var isTitleFocused: Bool
    @State private var currentTime = Date()
    @State private var selectionState = TextSelectionState()
    @State private var richTextView: RichNSTextView?
    @State private var isDictating = false

    // Floating toolbar state
    @State private var showFloatingToolbar: Bool = false
    @State private var toolbarPosition: CGPoint = .zero

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    // Top section with title and status
                    VStack(alignment: .leading, spacing: 12) {
                        // Page title input
                        TextField("Page Name + Press Enter", text: $page.title, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.lexendBold(size: 32, comicSans: isComicSansMode))
                            .lineSpacing(11.2)
                            .foregroundColor(.vibeyText)
                            .opacity(page.title.isEmpty ? 0.4 : 1.0)
                            .lineLimit(1...5)
                            .focused($isTitleFocused)
                            .onSubmit {
                                isTitleFocused = false
                                // Focus the rich text editor
                                DispatchQueue.main.async {
                                    richTextView?.window?.makeFirstResponder(richTextView)
                                }
                            }

                        // Context status
                        HStack(spacing: 4) {
                            Image(statusImageName)
                                .resizable()
                                .frame(width: 24, height: 24)

                            Text(statusText)
                                .font(.atkinsonRegular(size: 12, comicSans: isComicSansMode))
                                .foregroundColor(statusTextColor)
                                .kerning(0.84)
                        }
                        .onReceive(timer) { _ in
                            currentTime = Date()
                        }

                        // Send Page Context button
                        Button(action: {
                            onSendContext(page)
                        }) {
                            HStack(spacing: 10) {
                                Text("Send Page Context")
                                    .font(.atkinsonRegular(size: 16, comicSans: isComicSansMode))
                                    .foregroundColor(.white)
                                    .kerning(1.12)

                                Image(systemName: "return")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "1C1E22"))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.vibeyCardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(page.title.isEmpty && page.isEmpty ? 0.4 : 1.0)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 32)
                    .padding(.bottom, 16)

                    // Rich text editor (toolbar is now floating)
                    RichTextEditorWithRef(
                        content: $page.content,
                        selectionState: $selectionState,
                        textView: $richTextView,
                        isComicSansMode: isComicSansMode,
                        onSelectionChanged: { hasSelection, selectionRect in
                            if hasSelection, let rect = selectionRect {
                                // Position toolbar above the selection
                                let toolbarHeight: CGFloat = 44
                                let toolbarWidth: CGFloat = 400

                                // Get window height for coordinate conversion (window coords have origin at bottom)
                                let windowHeight = NSApp.keyWindow?.frame.height ?? geometry.size.height

                                // Convert Y coordinate (flip from bottom-origin to top-origin)
                                let flippedY = windowHeight - rect.maxY

                                // Position toolbar above the selection
                                let localX = max(16, min(rect.midX - toolbarWidth / 2, geometry.size.width - toolbarWidth - 16))
                                let localY = max(16, flippedY - toolbarHeight - 8)

                                toolbarPosition = CGPoint(x: localX + toolbarWidth / 2, y: localY + toolbarHeight / 2)
                                showFloatingToolbar = true
                            } else {
                                // Hide toolbar when no text is selected
                                showFloatingToolbar = false
                            }
                        },
                        onMoreIconClicked: { lineRect in
                            // Position toolbar near the line
                            let toolbarHeight: CGFloat = 44
                            let toolbarWidth: CGFloat = 400

                            // Get window height for coordinate conversion
                            let windowHeight = NSApp.keyWindow?.frame.height ?? geometry.size.height

                            // Convert Y coordinate (flip from bottom-origin to top-origin)
                            let flippedY = windowHeight - lineRect.maxY

                            let localX = max(16, min(lineRect.minX, geometry.size.width - toolbarWidth - 16))
                            let localY = max(16, flippedY - toolbarHeight - 8)

                            toolbarPosition = CGPoint(x: localX + toolbarWidth / 2, y: localY + toolbarHeight / 2)
                            showFloatingToolbar = true
                        },
                        onEscapePressed: {
                            showFloatingToolbar = false
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.trailing, 32)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Floating toolbar overlay
                if showFloatingToolbar {
                    FormattingToolbar(
                        selectionState: $selectionState,
                        isDictating: isDictating,
                        isFloating: true,
                        onBold: { applyBold() },
                        onItalic: { applyItalic() },
                        onUnderline: { applyUnderline() },
                        onStrikethrough: { applyStrikethrough() },
                        onHeading: { level in applyHeading(level) },
                        onTextColor: { color in applyTextColor(color) },
                        onBulletList: { applyBulletList() },
                        onNumberedList: { applyNumberedList() },
                        onCheckboxList: { applyCheckboxList() },
                        onDictation: { applyDictation() },
                        onInsertImage: { insertImageFromPicker() },
                        onLink: { urlString in applyLink(urlString) },
                        onConvertToEmbed: { urlString in convertLinkToEmbed(urlString) },
                        currentLinkURL: selectionState.linkURL
                    )
                    .fixedSize()
                    .position(toolbarPosition)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeOut(duration: 0.15), value: showFloatingToolbar)
                }

            }
        }
        .background(Color.vibeyBackground)
        .onAppear {
            if page.title.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTitleFocused = true
                }
            }
        }
    }

    // MARK: - Formatting Actions

    private func applyBold() {
        richTextView?.applyBold()
    }

    private func applyItalic() {
        richTextView?.applyItalic()
    }

    private func applyUnderline() {
        richTextView?.applyUnderline()
    }

    private func applyStrikethrough() {
        richTextView?.applyStrikethrough()
    }

    private func applyHeading(_ level: Int) {
        richTextView?.applyHeading(level)
    }

    private func applyTextColor(_ color: NSColor) {
        richTextView?.applyTextColor(color)
    }

    private func applyBulletList() {
        richTextView?.applyBulletList()
    }

    private func applyNumberedList() {
        richTextView?.applyNumberedList()
    }

    private func applyCheckboxList() {
        richTextView?.applyCheckboxList()
    }

    private func applyDictation() {
        // Set up callback if not already set
        if richTextView?.onDictationStateChanged == nil {
            richTextView?.onDictationStateChanged = { [self] dictating in
                isDictating = dictating
            }
        }
        richTextView?.toggleSystemDictation()
    }

    private func insertImageFromPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .bmp, .webP]
        panel.message = "Select an image to insert"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let image = NSImage(contentsOf: url) {
                    richTextView?.insertImage(image)
                }
            }
        }
    }

    private func applyLink(_ urlString: String?) {
        if let urlString = urlString {
            // Apply or update link
            richTextView?.applyLink(urlString)
        } else {
            // Remove link
            richTextView?.removeLink()
        }
    }

    private func convertLinkToEmbed(_ urlString: String) {
        guard let textView = richTextView, let textStorage = textView.textStorage else { return }

        // First select the full link range (in case cursor is just positioned in the link)
        textView.selectLinkAtCursor()

        // Get the selected range (now the full link)
        let range = textView.selectedRange()

        if range.length > 0 {
            // Delete the link text
            textStorage.beginEditing()
            textStorage.deleteCharacters(in: range)
            textStorage.endEditing()
            textView.setSelectedRange(NSRange(location: range.location, length: 0))
            textView.didChangeText()
        }

        // Insert the preview card at current position
        textView.insertLinkPreviewCard(urlString: urlString)
    }

    // MARK: - Status Properties

    private var statusImageName: String {
        switch page.status {
        case .notShared:
            return "PageStatusDefault"
        case .shared:
            return "PageStatusShared"
        case .contextLost:
            return "PageStatusRemoved"
        }
    }

    private var statusTextColor: Color {
        switch page.status {
        case .notShared:
            return Color(hex: "414346") // Grey
        case .shared:
            return .green
        case .contextLost:
            return .red
        }
    }

    private var statusText: String {
        switch page.status {
        case .shared:
            if let sharedAt = page.sharedAt {
                let interval = currentTime.timeIntervalSince(sharedAt)
                return "Context shared \(timeAgoString(interval))"
            }
            return "Context shared"
        case .notShared:
            return "Context not shared"
        case .contextLost:
            return "Context lost (terminal cleared)"
        }
    }

    private func timeAgoString(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        if seconds < 60 {
            return "less than 1 min ago"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}

// MARK: - Rich Text Editor with Reference

/// Wrapper to expose the NSTextView reference for formatting commands
struct RichTextEditorWithRef: NSViewRepresentable {
    @Binding var content: Data
    @Binding var selectionState: TextSelectionState
    @Binding var textView: RichNSTextView?
    var isComicSansMode: Bool = false
    var onSelectionChanged: ((Bool, NSRect?) -> Void)? = nil
    var onMoreIconClicked: ((NSRect) -> Void)? = nil
    var onEscapePressed: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.contentView.postsBoundsChangedNotifications = true

        let textView = RichNSTextView()
        textView.wantsLayer = true
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
        // Account for the left margin (hoverIconMargin) when setting text container width
        let textContainerWidth = max(scrollView.contentSize.width - RichNSTextView.hoverIconMargin, 100)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: textContainerWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false  // We manage width manually to account for margin

        // Default paragraph style with fixed line height
        let defaultFont = isComicSansMode
            ? NSFont(name: "Comic Sans MS", size: 16) ?? NSFont.systemFont(ofSize: 16)
            : NSFont.systemFont(ofSize: 16)
        let fixedLineHeight = ceil(defaultFont.ascender - defaultFont.descender + defaultFont.leading) + 8

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        paragraphStyle.minimumLineHeight = fixedLineHeight
        paragraphStyle.maximumLineHeight = fixedLineHeight
        textView.defaultParagraphStyle = paragraphStyle

        textView.typingAttributes = [
            .font: defaultFont,
            .foregroundColor: NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]

        scrollView.documentView = textView
        context.coordinator.textView = textView

        // Store reference
        DispatchQueue.main.async {
            self.textView = textView
        }

        // Wire up selection change callback
        let coordinator = context.coordinator
        textView.onSelectionChanged = { hasSelection, selectionRect in
            coordinator.parent.onSelectionChanged?(hasSelection, selectionRect)
        }

        // Wire up more icon click callback
        textView.onMoreIconClicked = { lineRect in
            coordinator.parent.onMoreIconClicked?(lineRect)
        }

        // Wire up escape key callback
        textView.onEscapePressed = {
            coordinator.parent.onEscapePressed?()
        }

        // Load initial content
        loadContent(into: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? RichNSTextView else { return }

        // Update reference if needed
        if self.textView !== textView {
            DispatchQueue.main.async {
                self.textView = textView
            }
        }

        // Update text container width on resize (accounting for left margin)
        let newWidth = max(scrollView.contentSize.width - RichNSTextView.hoverIconMargin, 100)
        if let textContainer = textView.textContainer,
           abs(textContainer.containerSize.width - newWidth) > 1 {
            textContainer.containerSize = NSSize(width: newWidth, height: CGFloat.greatestFiniteMagnitude)
        }

        // Update callbacks
        textView.onSelectionChanged = { hasSelection, selectionRect in
            context.coordinator.parent.onSelectionChanged?(hasSelection, selectionRect)
        }
        textView.onMoreIconClicked = { lineRect in
            context.coordinator.parent.onMoreIconClicked?(lineRect)
        }
        textView.onEscapePressed = {
            context.coordinator.parent.onEscapePressed?()
        }

        // Update content only if it changed externally
        if context.coordinator.isUpdating { return }

        // Don't reload content while there's uncommitted input (e.g., dictation, input method)
        if textView.hasMarkedText() { return }

        // Don't reload content while user has an active selection (prevents selection flicker)
        if textView.selectedRange().length > 0 { return }

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
                normalizeParagraphStyles(in: textView)
                return
            }
        }
        // Fall back to RTF (legacy format)
        if let attrString = NSAttributedString(rtf: content, documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attrString)
            normalizeParagraphStyles(in: textView)
        }
        // Fall back to plain text
        else if let plainText = String(data: content, encoding: .utf8) {
            // Use system font (San Francisco) for body text
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

    /// Ensure all paragraphs have consistent line height, list indentation, and marker font
    private func normalizeParagraphStyles(in textView: NSTextView) {
        guard let textStorage = textView.textStorage, textStorage.length > 0 else { return }

        let nsString = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let markerFont = NSFont.systemFont(ofSize: 16)

        // Fixed line height matching RichNSTextView
        let fixedLineHeight = ceil(markerFont.ascender - markerFont.descender + markerFont.leading) + 8

        textStorage.beginEditing()
        nsString.enumerateSubstrings(in: fullRange, options: .byParagraphs) { substring, paragraphRange, _, _ in
            guard let line = substring else { return }

            let isCheckbox = line.hasPrefix("☐\t") || line.hasPrefix("☑\t")
            let isBullet = line.hasPrefix("\u{2022}\t") || line.hasPrefix("•\t")
            let isNumbered = line.range(of: "^\\d+\\.\\t", options: .regularExpression) != nil
            let isList = isCheckbox || isBullet || isNumbered

            let style = NSMutableParagraphStyle()
            style.lineSpacing = 8
            style.minimumLineHeight = fixedLineHeight
            style.maximumLineHeight = fixedLineHeight
            if isList {
                let indentWidth: CGFloat = 20
                style.headIndent = indentWidth
                style.firstLineHeadIndent = 0
                style.tabStops = [NSTextTab(textAlignment: .left, location: indentWidth)]
                style.defaultTabInterval = indentWidth
            }

            textStorage.addAttribute(.paragraphStyle, value: style, range: paragraphRange)

            // Normalize font on list marker characters to prevent
            // fallback fonts with different metrics from causing line height shifts
            if isList && paragraphRange.length >= 2 {
                let markerLen: Int
                if isCheckbox || isBullet {
                    markerLen = 2 // marker + tab
                } else {
                    // Numbered: find tab position
                    if let tabIdx = line.firstIndex(of: "\t") {
                        markerLen = line.distance(from: line.startIndex, to: tabIdx) + 1
                    } else {
                        markerLen = 2
                    }
                }
                let markerRange = NSRange(location: paragraphRange.location, length: min(markerLen, paragraphRange.length))
                textStorage.addAttribute(.font, value: markerFont, range: markerRange)
            }
        }
        textStorage.endEditing()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditorWithRef
        weak var textView: RichNSTextView?
        var isUpdating = false

        init(_ parent: RichTextEditorWithRef) {
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
                // This shows what the NEXT typed character will look like
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

            // Check for link
            if let link = attrs[.link] {
                if let url = link as? URL {
                    state.linkURL = url.absoluteString
                } else if let urlString = link as? String {
                    state.linkURL = urlString
                }
            }

            return state
        }
    }
}

// MARK: - Terminal Panel
struct TerminalPanel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.isComicSansMode) var isComicSansMode

    var body: some View {
        ZStack {
            // Keep all terminal instances alive in background
            ForEach(appState.projects) { project in
                TerminalView(terminalState: project.terminalState, projectID: project.id, isComicSansMode: isComicSansMode)
                    .environmentObject(appState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(project.id == appState.currentProject?.id ? 1 : 0)
                    .allowsHitTesting(project.id == appState.currentProject?.id)
                    .id("\(project.id)-\(isComicSansMode)") // Force refresh when comic sans mode changes
            }

            // Show placeholder only when no projects exist
            if appState.projects.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.vibeyText.opacity(0.3))

                    Text("No Project Selected")
                        .font(.atkinsonRegular(size: 16, comicSans: isComicSansMode))
                        .foregroundColor(.vibeyText.opacity(0.7))

                    Text("Create or select a project to use the terminal")
                        .font(.atkinsonRegular(size: 14, comicSans: isComicSansMode))
                        .foregroundColor(.vibeyText.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.vibeyBackground)
            }
        }
        .background(Color.vibeyBackground)
        .overlay(
            Rectangle()
                .fill(Color(hex: "242529"))
                .frame(width: 2),
            alignment: .leading
        )
    }
}

// MARK: - Draggable Divider
struct DraggableDivider: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    var reverseDirection: Bool = false  // For right-side panels like terminal
    @State private var isDragging = false
    @State private var startWidth: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 24)
            .contentShape(Rectangle())
            .zIndex(1000)
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            startWidth = width
                            isDragging = true
                        }
                        // Reverse direction for right-side panels (terminal)
                        let translation = reverseDirection ? -value.translation.width : value.translation.width
                        let newWidth = startWidth + translation
                        width = min(max(newWidth, minWidth), maxWidth)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}

#Preview {
    MainContentView()
        .environmentObject({
            let state = AppState()
            state.createProject(name: "PennyPilot")
            return state
        }())
}
