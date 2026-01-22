//
//  ProjectsListView.swift
//  Vibey
//
//  Projects list page - shows all user projects
//  Allows creating, selecting, and managing projects
//

import SwiftUI

struct ProjectsListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.showingProjectsList) var showingProjectsList
    @State private var showingCreateProject = false
    @State private var newProjectName = ""

    var body: some View {
        ZStack {
            // Background grid pattern
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.vibeyBackground
                .ignoresSafeArea()
                .opacity(0.95)

            VStack(spacing: 0) {
                // Top navigation bar
                HStack {
                    // Logo on left
                    Image("VibeyLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 29.538)

                    Spacer()

                    // User profile on right
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.vibeyBlue)
                                .frame(width: 24, height: 24)

                            Text("WF")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        Text("Will Fuller")
                            .font(.atkinsonRegular(size: 16))
                            .foregroundColor(.white)
                            .kerning(1.12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.clear)
                    .cornerRadius(8)
                }
                .padding(16)
                .frame(height: 64)
                .background(.ultraThinMaterial.opacity(0.5))

                Spacer()

                // Centered projects card
                VStack(spacing: 32) {
                    // Header with title and create button
                    HStack {
                        Text("Your Projects")
                            .font(.lexendRegular(size: 32))
                            .foregroundColor(.vibeyText)

                        Spacer()

                        // Create Project button
                        Button(action: { showingCreateProject = true }) {
                            HStack(spacing: 10) {
                                Text("Create Project")
                                    .font(.atkinsonRegular(size: 16))
                                    .foregroundColor(.white)
                                    .kerning(1.12)

                                Image(systemName: "plus")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.vibeyBlue)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)

                    // Projects list
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(appState.projects) { project in
                                ProjectRow(
                                    project: project,
                                    isSelected: appState.currentProject?.id == project.id,
                                    onSelect: {
                                        appState.selectProject(project)
                                        showingProjectsList.wrappedValue = false
                                    },
                                    onDelete: {
                                        appState.deleteProject(project)
                                    }
                                )
                                .environmentObject(appState)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 48)
                .frame(width: 900, height: 672)
                .background(Color.vibeyBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.vibeyCardBorder, lineWidth: 1)
                )

                Spacer()
            }
        }
        .sheet(isPresented: $showingCreateProject) {
            CreateProjectSheet(
                projectName: $newProjectName,
                onCreate: {
                    if !newProjectName.isEmpty {
                        appState.createProject(name: newProjectName)
                        newProjectName = ""
                        showingCreateProject = false
                    }
                },
                onCancel: {
                    newProjectName = ""
                    showingCreateProject = false
                }
            )
        }
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    @EnvironmentObject var appState: AppState
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var showingMenu = false
    @State private var showingEditDialog = false
    @State private var showingDeleteConfirmation = false
    @State private var editedName = ""
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Cube icon
            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "1C1E22"))

                Image(systemName: "cube")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }

            // Project info
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.lexendBold(size: 20))
                    .foregroundColor(Color(hex: "EEEEEE"))
                    .kerning(1.4)

                Text("Last edited \(timeAgo(project.updatedAt))")
                    .font(.atkinsonRegular(size: 12))
                    .foregroundColor(Color(hex: "EEEEEE"))
                    .kerning(0.84)
            }

            Spacer()

            // More menu button
            Image("More")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(.white)
                .onTapGesture {
                    showingMenu = true
                }
        }
        .padding(24)
        .background(isHovered ? Color(hex: "1C1E22") : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .confirmationDialog("", isPresented: $showingMenu, titleVisibility: .hidden) {
            Button("Edit") {
                editedName = project.name
                showingEditDialog = true
            }
            Button("Delete", role: .destructive) {
                showingDeleteConfirmation = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Edit Project Name", isPresented: $showingEditDialog) {
            TextField("Project name", text: $editedName)
            Button("Cancel", role: .cancel) {
                editedName = ""
            }
            Button("Save") {
                if !editedName.isEmpty {
                    renameProject()
                }
            }
        } message: {
            Text("Enter a new name for this project")
        }
        .alert("Delete Project?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \"\(project.name)\"? This action cannot be undone.")
        }
    }

    private func renameProject() {
        appState.renameProject(project.id, newName: editedName)
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)

        if minutes < 1 {
            return "just now"
        } else if minutes < 60 {
            return "\(minutes)min ago"
        } else if minutes < 1440 {
            return "\(minutes / 60)h ago"
        } else {
            return "\(minutes / 1440)d ago"
        }
    }
}

// MARK: - Create Project Sheet

struct CreateProjectSheet: View {
    @Binding var projectName: String
    let onCreate: () -> Void
    let onCancel: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("New Project")
                    .font(.lexendRegular(size: 32))
                    .foregroundColor(.vibeyText)
                    .kerning(4.8)

                Text("What is the name of your project?")
                    .font(.atkinsonRegular(size: 20))
                    .foregroundColor(.vibeyText)
                    .kerning(1.4)
            }

            // Input field
            TextField("Project name", text: $projectName)
                .textFieldStyle(.plain)
                .font(.custom("Inter-Medium", size: 16))
                .foregroundColor(projectName.isEmpty ? Color.white.opacity(0.6) : .white)
                .padding(20)
                .background(Color.vibeyBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.vibeyCardBorder, lineWidth: 1)
                )
                .focused($isTextFieldFocused)

            // Buttons
            HStack(spacing: 16) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.atkinsonRegular(size: 16))
                        .foregroundColor(.white)
                        .kerning(1.12)
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

                Spacer()

                Button(action: onCreate) {
                    HStack(spacing: 10) {
                        Text("Create Project")
                            .font(.atkinsonRegular(size: 16))
                            .foregroundColor(.white)
                            .kerning(1.12)

                        Image(systemName: "plus")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(projectName.isEmpty ? Color.vibeyCardBorder : Color.vibeyBlue)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(projectName.isEmpty)
            }
        }
        .padding(64)
        .frame(width: 500)
        .background(Color.vibeyBackground)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

#Preview {
    ProjectsListView()
        .environmentObject({
            let state = AppState()
            state.createProject(name: "PennyPilot")
            state.createProject(name: "Contextly")
            state.createProject(name: "Flowmark")
            return state
        }())
}
