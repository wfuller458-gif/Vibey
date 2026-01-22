//
//  FirstProjectView.swift
//  Vibey
//
//  Create first project during onboarding
//  Matches Figma design: centered modal with nav bar
//

import SwiftUI

struct FirstProjectView: View {
    @EnvironmentObject var appState: AppState
    let onComplete: () -> Void

    @State private var projectName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            // Background with grid pattern
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Dark background overlay
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

                // Centered modal card
                VStack(spacing: 64) {
                    // Title and subtitle
                    VStack(spacing: 32) {
                        VStack(spacing: 8) {
                            Text("New Project")
                                .font(.lexendRegular(size: 32))
                                .foregroundColor(.vibeyText)
                                .kerning(4.8)
                                .lineSpacing(1.35)

                            Text("What is the name of your project?")
                                .font(.atkinsonRegular(size: 20))
                                .foregroundColor(.vibeyText)
                                .kerning(1.4)
                                .multilineTextAlignment(.center)
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
                    }

                    // Buttons
                    HStack(spacing: 16) {
                        // Cancel button (secondary)
                        Button(action: {
                            // TODO: Handle cancel - maybe go back to previous step
                        }) {
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

                        // Create Project button (primary)
                        Button(action: {
                            if !projectName.isEmpty {
                                appState.createProject(name: projectName)
                                onComplete()
                            }
                        }) {
                            HStack(spacing: 10) {
                                Text("Create Project")
                                    .font(.atkinsonRegular(size: 16))
                                    .foregroundColor(.white)
                                    .kerning(1.12)

                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .regular))
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
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.vibeyCardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 4)

                Spacer()
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

#Preview {
    FirstProjectView(onComplete: {})
        .environmentObject(AppState())
}
