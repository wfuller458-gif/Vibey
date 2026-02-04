//
//  VibeyApp.swift
//  Vibey
//
//  Main entry point for the Vibey macOS application
//  A calm, focused app for writing, organizing, and sending prompts to Claude Code
//

import SwiftUI
import AppKit
import CoreText

// MARK: - Window Delegate
class WindowDelegate: NSObject, NSWindowDelegate {
    weak var appState: AppState?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Close Vibey?"
        alert.informativeText = "All terminal history will be deleted for all projects. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // User clicked "Close" - clear all page statuses before closing
            if let appState = appState {
                for project in appState.projects {
                    appState.clearAllPageStatuses(for: project.id)
                }
            }

            // Terminate the app
            NSApplication.shared.terminate(nil)
            return true
        } else {
            // User clicked "Cancel" - don't close the window
            return false
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var windowDelegate = WindowDelegate()
    weak var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set delegate on the main window to intercept close events
        if let window = NSApplication.shared.windows.first {
            windowDelegate.appState = appState
            window.delegate = windowDelegate
        }
    }
}

@main
struct VibeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // AppState manages the global state of the app (authentication, current project, etc.)
    @StateObject private var appState = AppState()
    @State private var showingProjectsList = false

    init() {
        // Load custom fonts at app startup
        loadCustomFonts()
    }

    func loadCustomFonts() {
        let fontFiles = [
            "Lexend-Regular",
            "Lexend-Bold",
            "AtkinsonHyperlegible-Regular",
            "AtkinsonHyperlegible-Bold"
        ]

        for fontFile in fontFiles {
            guard let fontURL = Bundle.main.url(forResource: fontFile, withExtension: "ttf") else {
                print("⚠️ Failed to find font: \(fontFile).ttf")
                continue
            }

            guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
                  let font = CGFont(fontDataProvider) else {
                print("⚠️ Failed to load font data: \(fontFile).ttf")
                continue
            }

            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterGraphicsFont(font, &error) {
                if let error = error?.takeRetainedValue() {
                    let errorDesc = CFErrorCopyDescription(error) as String
                    print("⚠️ Failed to register font \(fontFile): \(errorDesc)")
                }
            } else {
                if let postScriptName = font.postScriptName {
                    print("✅ Successfully registered font: \(postScriptName)")
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Keep main app always rendered (keeps terminal alive)
                MainContentView()
                    .environmentObject(appState)
                    .environment(\.showingProjectsList, $showingProjectsList)
                    .environment(\.isComicSansMode, appState.isComicSansMode)

                // Show projects list on top when needed
                if showingProjectsList || appState.currentProject == nil {
                    ProjectsListView()
                        .environmentObject(appState)
                        .environment(\.showingProjectsList, $showingProjectsList)
                        .environment(\.isComicSansMode, appState.isComicSansMode)
                }
            }
            .onAppear {
                // Pass appState to delegate
                appDelegate.appState = appState
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
    }
}

// Environment key for projects list navigation
private struct ShowingProjectsListKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var showingProjectsList: Binding<Bool> {
        get { self[ShowingProjectsListKey.self] }
        set { self[ShowingProjectsListKey.self] = newValue }
    }
}
