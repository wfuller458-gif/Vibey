//
//  AppState.swift
//  Vibey
//
//  Manages global application state
//  - Current selected project
//  - Onboarding flow state
//

import SwiftUI

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

    // Whether onboarding has been completed
    @Published var hasCompletedOnboarding: Bool = false


    // MARK: - Initialization

    init() {
        // Load saved state
        loadState()
    }

    // MARK: - State Management

    func loadState() {
        // Load saved onboarding state from UserDefaults
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        // Load saved projects from UserDefaults
        if let projectsData = UserDefaults.standard.data(forKey: "projects") {
            if let decodedProjects = try? JSONDecoder().decode([Project].self, from: projectsData) {
                projects = decodedProjects
            }
        }

        // Load current project ID and find it in projects
        if let currentProjectID = UserDefaults.standard.string(forKey: "currentProjectID"),
           let uuid = UUID(uuidString: currentProjectID) {
            currentProject = projects.first { $0.id == uuid }
        }
    }

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

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    // MARK: - Project Methods

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
}
