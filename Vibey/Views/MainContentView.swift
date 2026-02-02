//
//  MainContentView.swift
//  Vibey
//
//  Main app interface matching Figma design
//  3-panel layout: Sidebar | Page Editor | Terminal
//

import SwiftUI
import AppKit

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
                                .id(pageID) // Force view to refresh when switching pages
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

        // Use bracketed paste mode to prevent line-by-line execution
        // This tells the terminal "this is pasted text, don't execute each line"
        // ESC[200~ = start bracketed paste, ESC[201~ = end bracketed paste
        let bracketedText = "\u{1b}[200~\(contextText)\u{1b}[201~"

        currentProject.terminalState.sendText(bracketedText)

        // After a small delay, send Enter to submit to Claude
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            currentProject.terminalState.sendText("\r")
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

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
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

            // Formatting toolbar
            FormattingToolbar(
                selectionState: $selectionState,
                onBold: { applyBold() },
                onItalic: { applyItalic() },
                onUnderline: { applyUnderline() },
                onStrikethrough: { applyStrikethrough() },
                onHeading: { level in applyHeading(level) },
                onTextColor: { color in applyTextColor(color) },
                onBulletList: { applyBulletList() },
                onNumberedList: { applyNumberedList() }
            )

            // Rich text editor
            RichTextEditorWithRef(
                content: $page.content,
                selectionState: $selectionState,
                textView: $richTextView,
                isComicSansMode: isComicSansMode
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

        // Store reference
        DispatchQueue.main.async {
            self.textView = textView
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
