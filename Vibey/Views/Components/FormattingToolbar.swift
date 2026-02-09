//
//  FormattingToolbar.swift
//  Vibey
//
//  Toolbar for rich text formatting
//  H1/H2/H3, Bold, Italic, Underline, Strikethrough, Color, Lists
//

import SwiftUI
import AppKit

struct FormattingToolbar: View {
    @Binding var selectionState: TextSelectionState
    var isDictating: Bool = false
    var isFloating: Bool = false  // Whether to display as floating popup
    var onBold: () -> Void
    var onItalic: () -> Void
    var onUnderline: () -> Void
    var onStrikethrough: () -> Void
    var onHeading: (Int) -> Void
    var onTextColor: (NSColor) -> Void
    var onBulletList: () -> Void
    var onNumberedList: () -> Void
    var onCheckboxList: () -> Void
    var onDictation: (() -> Void)? = nil
    var onInsertImage: (() -> Void)? = nil

    @State private var showingColorPicker = false

    var body: some View {
        HStack(spacing: 4) {
            // Heading buttons
            FormatButton(label: "H1", isActive: selectionState.fontSize >= 28) {
                onHeading(1)
            }

            FormatButton(label: "H2", isActive: selectionState.fontSize >= 22 && selectionState.fontSize < 28) {
                onHeading(2)
            }

            FormatButton(label: "H3", isActive: selectionState.fontSize >= 18 && selectionState.fontSize < 22) {
                onHeading(3)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // Bold (Cmd+B)
            FormatButton(systemImage: "bold", isActive: selectionState.isBold) {
                onBold()
            }
            .keyboardShortcut("b", modifiers: .command)

            // Italic (Cmd+I)
            FormatButton(systemImage: "italic", isActive: selectionState.isItalic) {
                onItalic()
            }
            .keyboardShortcut("i", modifiers: .command)

            // Underline (Cmd+U)
            FormatButton(systemImage: "underline", isActive: selectionState.isUnderline) {
                onUnderline()
            }
            .keyboardShortcut("u", modifiers: .command)

            // Strikethrough
            FormatButton(systemImage: "strikethrough", isActive: selectionState.isStrikethrough) {
                onStrikethrough()
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // Text color
            Button(action: {
                showingColorPicker.toggle()
            }) {
                ZStack {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 14))
                        .foregroundColor(.white)

                    // Color indicator
                    Circle()
                        .fill(Color(nsColor: selectionState.textColor))
                        .frame(width: 6, height: 6)
                        .offset(x: 6, y: 6)
                }
                .frame(width: 28, height: 28)
                .background(showingColorPicker ? Color.white.opacity(0.2) : Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingColorPicker, arrowEdge: .bottom) {
                ColorPickerPopover(selectedColor: selectionState.textColor) { color in
                    onTextColor(color)
                    showingColorPicker = false
                }
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // Bullet list
            FormatButton(systemImage: "list.bullet", isActive: selectionState.hasBulletList) {
                onBulletList()
            }

            // Numbered list
            FormatButton(systemImage: "list.number", isActive: selectionState.hasNumberedList) {
                onNumberedList()
            }

            // Checkbox list
            FormatButton(systemImage: "checklist", isActive: selectionState.hasCheckbox) {
                onCheckboxList()
            }

            // Insert image button
            if let onInsertImage = onInsertImage {
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 4)

                FormatButton(systemImage: "photo", isActive: false) {
                    onInsertImage()
                }
                .help("Insert image")
            }

            // Dictation button
            if let onDictation = onDictation {
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 4)

                FormatButton(systemImage: isDictating ? "mic.fill" : "mic", isActive: isDictating) {
                    onDictation()
                }
                .help(isDictating ? "Stop dictation" : "Start dictation")
            }

            if !isFloating {
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "1C1E22"))
        .cornerRadius(isFloating ? 8 : 0)
        .shadow(color: isFloating ? Color.black.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
        .overlay(
            Group {
                if isFloating {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.vibeyCardBorder, lineWidth: 1)
                } else {
                    Rectangle()
                        .fill(Color.vibeyCardBorder)
                        .frame(height: 1)
                        .frame(maxWidth: .infinity, alignment: .bottom)
                }
            },
            alignment: .bottom
        )
    }
}

// MARK: - Format Button

struct FormatButton: View {
    var label: String? = nil
    var systemImage: String? = nil
    var isActive: Bool
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Group {
                if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: isActive ? .bold : .medium))
                        .foregroundColor(isActive ? .vibeyBlue : .white)
                } else if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? .vibeyBlue : .white)
                }
            }
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? Color.vibeyBlue.opacity(0.2) : (isHovered ? Color.white.opacity(0.1) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Color Picker Popover

struct ColorPickerPopover: View {
    let selectedColor: NSColor
    let onColorSelected: (NSColor) -> Void

    // Preset colors
    let colors: [NSColor] = [
        // Row 1 - Basic colors
        NSColor(red: 235/255, green: 236/255, blue: 240/255, alpha: 1.0), // Default text
        NSColor.white,
        NSColor(red: 156/255, green: 163/255, blue: 175/255, alpha: 1.0), // Gray
        NSColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0),   // Red
        NSColor(red: 249/255, green: 115/255, blue: 22/255, alpha: 1.0),  // Orange
        NSColor(red: 234/255, green: 179/255, blue: 8/255, alpha: 1.0),   // Yellow

        // Row 2 - More colors
        NSColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1.0),   // Green
        NSColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0),  // Teal
        NSColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1.0),  // Blue
        NSColor(red: 99/255, green: 102/255, blue: 241/255, alpha: 1.0),  // Indigo
        NSColor(red: 168/255, green: 85/255, blue: 247/255, alpha: 1.0),  // Purple
        NSColor(red: 236/255, green: 72/255, blue: 153/255, alpha: 1.0),  // Pink
    ]

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 4), count: 6), spacing: 4) {
                ForEach(colors, id: \.self) { color in
                    Button(action: {
                        onColorSelected(color)
                    }) {
                        Circle()
                            .fill(Color(nsColor: color))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(color == selectedColor ? Color.white : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(hex: "1C1E22"))
    }
}

// MARK: - Preview

struct FormattingToolbar_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }

    struct PreviewWrapper: View {
        @State private var state = TextSelectionState()
        @State private var isDictating = false

        var body: some View {
            VStack {
                FormattingToolbar(
                    selectionState: $state,
                    isDictating: isDictating,
                    onBold: { state.isBold.toggle() },
                    onItalic: { state.isItalic.toggle() },
                    onUnderline: { state.isUnderline.toggle() },
                    onStrikethrough: { state.isStrikethrough.toggle() },
                    onHeading: { _ in },
                    onTextColor: { color in state.textColor = color },
                    onBulletList: { state.hasBulletList.toggle() },
                    onNumberedList: { state.hasNumberedList.toggle() },
                    onCheckboxList: { state.hasCheckbox.toggle() },
                    onDictation: { isDictating.toggle() },
                    onInsertImage: { print("Insert image") }
                )

                Spacer()
            }
            .frame(width: 500, height: 100)
            .background(Color.vibeyBackground)
        }
    }
}