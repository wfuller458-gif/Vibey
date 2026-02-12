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
        alert.informativeText = "Your pages and projects are saved. Terminal session data will be lost when you close the app."
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

            // Force UserDefaults to save immediately before terminating
            UserDefaults.standard.synchronize()

            // Terminate the app
            NSApplication.shared.terminate(nil)
            return true
        } else {
            // User clicked "Cancel" - don't close the window
            return false
        }
    }
}

// MARK: - Window Accessor (sets NSWindowDelegate from SwiftUI)
struct WindowAccessor: NSViewRepresentable {
    let windowDelegate: WindowDelegate

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.delegate = windowDelegate
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-set delegate in case SwiftUI replaced it
        if let window = nsView.window, window.delegate !== windowDelegate {
            window.delegate = windowDelegate
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var windowDelegate = WindowDelegate()
    weak var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Send analytics ping
        sendAnalyticsPing()
    }

    private func sendAnalyticsPing() {
        // Get or create device ID for tracking
        let deviceId = getOrCreateDeviceId()

        // Get license key from UserDefaults (or nil for trial users)
        let licenseKey = UserDefaults.standard.string(forKey: "licenseKey")

        // Get trial end date
        let trialEndDate = UserDefaults.standard.object(forKey: "trialEndDate") as? Date

        // Get app version
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        // Build request
        guard let url = URL(string: "https://vibey-backend-production-5589.up.railway.app/ping") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "deviceId": deviceId,
            "appVersion": appVersion
        ]

        if let licenseKey = licenseKey {
            body["licenseKey"] = licenseKey
        }

        if let trialEndDate = trialEndDate {
            body["trialEndDate"] = Int(trialEndDate.timeIntervalSince1970 * 1000)
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // Fire and forget - don't block app launch
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("Analytics ping failed: \(error.localizedDescription)")
            } else {
                print("Analytics ping sent successfully")
            }
        }.resume()
    }

    private func getOrCreateDeviceId() -> String {
        let key = "vibeyDeviceId"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
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
            VStack(spacing: 0) {
                // Update banner - full width yellow
                if appState.updateAvailable {
                    UpdateBanner(version: appState.latestVersion ?? "")
                }

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
            }
            .background(WindowAccessor(windowDelegate: appDelegate.windowDelegate))
            .onAppear {
                // Pass appState to delegate and window delegate
                appDelegate.appState = appState
                appDelegate.windowDelegate.appState = appState
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
