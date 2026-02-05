//
//  AppState.swift
//  Vibey
//
//  Manages global application state
//  - Current selected project
//

import SwiftUI
import AppKit

// MARK: - Subscription Enums

enum SubscriptionStatus: String, Codable {
    case trial          // In 7-day free trial
    case comicSansTrial // Second 7-day trial with Comic Sans punishment
    case active         // Paid and active
    case paymentFailed  // Payment issue
    case cancelled      // Cancelled but still in paid period
    case expired        // Both trials expired
}

enum SubscriptionPlan: String, Codable {
    case monthly
    case yearly
}

// MARK: - Validation Response

struct ValidationResponse: Codable {
    let valid: Bool
    let plan: String?
    let renewsOn: Int?  // Unix timestamp
    let reason: String?
}

// Observable object that can be accessed throughout the app via @EnvironmentObject
class AppState: ObservableObject {
    // MARK: - Published Properties
    // These properties trigger UI updates when changed

    // Currently selected project
    @Published var currentProject: Project?

    // All user's projects
    @Published var projects: [Project] = []

    // Whether we're currently loading data
    @Published var isLoading: Bool = false

    // Any error messages to display to user
    @Published var errorMessage: String?

    // MARK: - Subscription Properties

    // License key entered by user
    @Published var licenseKey: String?

    // Current subscription status
    @Published var subscriptionStatus: SubscriptionStatus = .trial

    // When first trial started (never changes once set)
    @Published var trialStartDate: Date?

    // When trial ends
    @Published var trialEndDate: Date?

    // When subscription renews (for active subscriptions)
    @Published var renewalDate: Date?

    // Last time we successfully validated
    @Published var lastValidationDate: Date?

    // Subscription plan type
    @Published var subscriptionPlan: SubscriptionPlan?

    // Track if user ever had a paid subscription (for showing correct expired popup)
    @Published var hadPaidSubscription: Bool = false

    // Comic Sans mode - activated after first trial expires
    var isComicSansMode: Bool {
        return subscriptionStatus == .comicSansTrial
    }

    // MARK: - Initialization

    init() {
        // Load saved state
        loadState()

        // Check subscription status on launch
        Task {
            await checkSubscriptionStatus()
        }
    }

    // MARK: - State Management

    func loadState() {
        // Load saved projects from UserDefaults
        if let projectsData = UserDefaults.standard.data(forKey: "projects") {
            // Try to decode with the new Data content format
            if let decodedProjects = try? JSONDecoder().decode([Project].self, from: projectsData) {
                projects = decodedProjects
            } else {
                // Migration: try to decode with legacy String content format
                projects = migrateProjectsFromLegacyFormat(projectsData)
            }
        }

        // Load current project ID and find it in projects
        if let currentProjectID = UserDefaults.standard.string(forKey: "currentProjectID"),
           let uuid = UUID(uuidString: currentProjectID) {
            currentProject = projects.first { $0.id == uuid }
        }

        // Load subscription data
        licenseKey = UserDefaults.standard.string(forKey: "licenseKey")

        if let statusString = UserDefaults.standard.string(forKey: "subscriptionStatus"),
           let status = SubscriptionStatus(rawValue: statusString) {
            subscriptionStatus = status
        }

        if let planString = UserDefaults.standard.string(forKey: "subscriptionPlan"),
           let plan = SubscriptionPlan(rawValue: planString) {
            subscriptionPlan = plan
        }

        trialStartDate = UserDefaults.standard.object(forKey: "trialStartDate") as? Date
        trialEndDate = UserDefaults.standard.object(forKey: "trialEndDate") as? Date
        renewalDate = UserDefaults.standard.object(forKey: "renewalDate") as? Date
        lastValidationDate = UserDefaults.standard.object(forKey: "lastValidationDate") as? Date
        hadPaidSubscription = UserDefaults.standard.bool(forKey: "hadPaidSubscription")
    }

    // MARK: - Migration

    /// Migrate projects from legacy format (String content) to new format (Data content)
    private func migrateProjectsFromLegacyFormat(_ data: Data) -> [Project] {
        // Define legacy types for decoding
        struct LegacyPage: Codable {
            let id: UUID
            let projectID: UUID
            var title: String
            var content: String  // Legacy: String instead of Data
            let createdAt: Date
            var updatedAt: Date
            var status: PageStatus
            var sharedAt: Date?
        }

        struct LegacyProject: Codable {
            let id: UUID
            var name: String
            let createdAt: Date
            var updatedAt: Date
            var terminalState: TerminalState
            var pages: [LegacyPage]
        }

        guard let legacyProjects = try? JSONDecoder().decode([LegacyProject].self, from: data) else {
            return []
        }

        // Convert legacy projects to new format
        var newProjects: [Project] = []

        for legacyProject in legacyProjects {
            var project = Project(
                id: legacyProject.id,
                name: legacyProject.name,
                createdAt: legacyProject.createdAt,
                updatedAt: legacyProject.updatedAt
            )
            project.terminalState = legacyProject.terminalState

            // Convert legacy pages
            project.pages = legacyProject.pages.map { legacyPage in
                Page(
                    id: legacyPage.id,
                    projectID: legacyPage.projectID,
                    title: legacyPage.title,
                    plainTextContent: legacyPage.content,
                    createdAt: legacyPage.createdAt,
                    updatedAt: legacyPage.updatedAt,
                    status: legacyPage.status,
                    sharedAt: legacyPage.sharedAt
                )
            }

            newProjects.append(project)
        }

        // Save migrated projects
        if let encoded = try? JSONEncoder().encode(newProjects) {
            UserDefaults.standard.set(encoded, forKey: "projects")
        }

        return newProjects
    }

    // MARK: - Project Methods

    private func saveProjects() {
        // Save projects to UserDefaults
        if let encoded = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(encoded, forKey: "projects")
        }

        // Save current project ID
        if let currentProjectID = currentProject?.id.uuidString {
            UserDefaults.standard.set(currentProjectID, forKey: "currentProjectID")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentProjectID")
        }
    }

    func createProject(name: String) {
        let newProject = Project(name: name)
        projects.append(newProject)
        currentProject = newProject

        // Save to UserDefaults
        saveProjects()
    }

    func selectProject(_ project: Project) {
        currentProject = project

        // Save current project selection
        saveProjects()
    }

    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        if currentProject?.id == project.id {
            currentProject = projects.first
        }

        // Save changes to UserDefaults
        saveProjects()
    }

    func renameProject(_ projectID: UUID, newName: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].name = newName
        projects[index].updatedAt = Date()

        // Update currentProject if it's the one being renamed
        if currentProject?.id == projectID {
            currentProject = projects[index]
        }

        saveProjects()
    }

    // MARK: - Page Methods

    func addPage(_ page: Page, to projectID: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].pages.append(page)

        // Update currentProject if it's the one being modified
        if currentProject?.id == projectID {
            currentProject = projects[index]
        }

        saveProjects()
    }

    func deletePage(_ pageID: UUID, from projectID: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[projectIndex].pages.removeAll { $0.id == pageID }

        // Update currentProject if it's the one being modified
        if currentProject?.id == projectID {
            currentProject = projects[projectIndex]
        }

        saveProjects()
    }

    func updatePageStatus(_ pageID: UUID, status: PageStatus, sharedAt: Date?) {
        // Find the project and page
        for projectIndex in projects.indices {
            if let pageIndex = projects[projectIndex].pages.firstIndex(where: { $0.id == pageID }) {
                projects[projectIndex].pages[pageIndex].status = status
                projects[projectIndex].pages[pageIndex].sharedAt = sharedAt

                // Update currentProject if it's the one being modified
                if currentProject?.id == projects[projectIndex].id {
                    currentProject = projects[projectIndex]
                }

                saveProjects()
                return
            }
        }
    }

    func clearAllPageStatuses(for projectID: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }

        for pageIndex in projects[projectIndex].pages.indices {
            // If page was previously shared, mark as context lost (red)
            // If page was never shared, keep as not shared (grey)
            if projects[projectIndex].pages[pageIndex].status == .shared {
                projects[projectIndex].pages[pageIndex].status = .contextLost
            }
            projects[projectIndex].pages[pageIndex].sharedAt = nil
        }

        // Update currentProject if it's the one being modified
        if currentProject?.id == projectID {
            currentProject = projects[projectIndex]
        }

        saveProjects()
    }

    // MARK: - Subscription Methods

    func checkSubscriptionStatus() async {
        // If we have a license key, validate it
        if let key = licenseKey {
            await validateLicense(key)
            return
        }

        // No license key - check trial status
        checkTrialStatus()
    }

    func checkTrialStatus() {
        let now = Date()

        // ⚠️ DEBUG: Change this to preview different trial states
        // Options: 0 = day 1 (7 days left), 6 = last day of normal trial,
        //          7 = first day of Comic Sans, 13 = last day of Comic Sans,
        //          14 = expired
        // Set to -1 for normal behavior before release!
        let debugDaysIntoTrial = -1  // Normal behavior

        // Reset trial if in debug mode
        if debugDaysIntoTrial >= 0 {
            let debugStartDate = Calendar.current.date(byAdding: .day, value: -debugDaysIntoTrial, to: now)!
            trialStartDate = debugStartDate
            UserDefaults.standard.set(debugStartDate, forKey: "trialStartDate")
        }

        // First launch - set trial start date (never changes)
        if trialStartDate == nil {
            let startDate = now
            trialStartDate = startDate
            UserDefaults.standard.set(startDate, forKey: "trialStartDate")

            // Set first trial end date (7 days from start)
            let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
            trialEndDate = endDate
            UserDefaults.standard.set(endDate, forKey: "trialEndDate")
            subscriptionStatus = .trial
            UserDefaults.standard.set(subscriptionStatus.rawValue, forKey: "subscriptionStatus")
            return
        }

        guard let startDate = trialStartDate else { return }

        // Calculate days since trial started
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: now).day ?? 0

        if daysSinceStart < 7 {
            // First 7 days - normal trial
            subscriptionStatus = .trial
        } else if daysSinceStart < 14 {
            // Days 8-14 - Comic Sans trial!
            subscriptionStatus = .comicSansTrial
            // Update trial end date to day 14
            if trialEndDate != Calendar.current.date(byAdding: .day, value: 14, to: startDate) {
                trialEndDate = Calendar.current.date(byAdding: .day, value: 14, to: startDate)
                UserDefaults.standard.set(trialEndDate, forKey: "trialEndDate")
            }
        } else {
            // After 14 days - fully expired
            subscriptionStatus = .expired
        }

        UserDefaults.standard.set(subscriptionStatus.rawValue, forKey: "subscriptionStatus")
    }

    var trialDaysRemaining: Int {
        guard let startDate = trialStartDate else { return 0 }
        let now = Date()
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: now).day ?? 0

        if subscriptionStatus == .trial {
            // First trial: days 0-6, show 7 down to 1
            return max(0, 7 - daysSinceStart)
        } else if subscriptionStatus == .comicSansTrial {
            // Comic Sans trial: days 7-13, show 7 down to 1
            return max(0, 14 - daysSinceStart)
        }
        return 0
    }

    var isSubscriptionValid: Bool {
        switch subscriptionStatus {
        case .trial, .comicSansTrial, .active, .cancelled:
            return true
        case .paymentFailed, .expired:
            return false
        }
    }

    func validateLicense(_ key: String) async {
        let apiURL = "https://vibey-backend-production-5589.up.railway.app/validate"

        guard let url = URL(string: apiURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["key": key]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(ValidationResponse.self, from: data)

            await MainActor.run {
                if response.valid {
                    // Valid license
                    licenseKey = key
                    subscriptionStatus = .active
                    lastValidationDate = Date()

                    // Save plan type
                    if let planString = response.plan {
                        subscriptionPlan = SubscriptionPlan(rawValue: planString)
                        UserDefaults.standard.set(planString, forKey: "subscriptionPlan")
                    }

                    // Save renewal date
                    if let renewsOnTimestamp = response.renewsOn {
                        renewalDate = Date(timeIntervalSince1970: TimeInterval(renewsOnTimestamp))
                        UserDefaults.standard.set(renewalDate, forKey: "renewalDate")
                    }

                    // Mark that user has had a paid subscription (for expired popup logic)
                    hadPaidSubscription = true
                    UserDefaults.standard.set(true, forKey: "hadPaidSubscription")

                    // Persist
                    UserDefaults.standard.set(key, forKey: "licenseKey")
                    UserDefaults.standard.set(subscriptionStatus.rawValue, forKey: "subscriptionStatus")
                    UserDefaults.standard.set(lastValidationDate, forKey: "lastValidationDate")
                } else {
                    // Invalid or expired license - only set to expired if they previously had a paid subscription
                    // If they're in trial and enter a wrong key, keep them in trial
                    if hadPaidSubscription {
                        subscriptionStatus = .expired
                        UserDefaults.standard.set(subscriptionStatus.rawValue, forKey: "subscriptionStatus")
                    }
                    // Clear the invalid license key
                    licenseKey = nil
                    UserDefaults.standard.removeObject(forKey: "licenseKey")
                }
            }
        } catch {
            // Validation failed - use grace period
            handleValidationError()
        }
    }

    private func handleValidationError() {
        // 7 day grace period for offline usage
        let gracePeriod: TimeInterval = 7 * 24 * 60 * 60

        if let lastValid = lastValidationDate {
            if Date().timeIntervalSince(lastValid) < gracePeriod {
                // Still within grace period - allow usage
                subscriptionStatus = .active
                return
            }
        }

        // Grace period expired or never validated
        subscriptionStatus = .expired
    }

    func startSubscriptionMonitoring() {
        // Validate once per day
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            Task {
                await self?.checkSubscriptionStatus()
            }
        }
    }

    func activateLicense(_ key: String) async -> Bool {
        await validateLicense(key)
        return subscriptionStatus == .active
    }

    func openSubscriptionPortal() {
        // Opens vibey.codes where user can click "Manage Subscription"
        if let url = URL(string: "https://www.vibey.codes") {
            NSWorkspace.shared.open(url)
        }
    }

    func openSubscribePage() {
        // Opens dedicated upgrade page
        if let url = URL(string: "https://www.vibey.codes/upgrade") {
            NSWorkspace.shared.open(url)
        }
    }
}
