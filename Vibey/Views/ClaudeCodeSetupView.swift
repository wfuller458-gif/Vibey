//
//  ClaudeCodeSetupView.swift
//  Vibey
//
//  Setup screen for installing Claude Code CLI
//

import SwiftUI

struct ClaudeCodeSetupView: View {
    @ObservedObject var detector: ClaudeCodeDetector
    let onComplete: () -> Void
    @Environment(\.isComicSansMode) var isComicSansMode

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
                    Image("VibeyLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 29.538)

                    Spacer()
                }
                .padding(16)
                .frame(height: 64)
                .background(.ultraThinMaterial.opacity(0.5))

                Spacer()

                // Centered setup card
                VStack(spacing: 48) {
                    VStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.vibeyBlue.opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: "terminal.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.vibeyBlue)
                        }

                        // Title
                        Text("Claude Code CLI Required")
                            .font(.lexendRegular(size: 32, comicSans: isComicSansMode))
                            .foregroundColor(.vibeyText)
                            .kerning(4.8)

                        // Description
                        Text("Vibey uses the Claude Code CLI to power its terminal.\nWe'll install it for you automatically.")
                            .font(.atkinsonRegular(size: 16, comicSans: isComicSansMode))
                            .foregroundColor(.vibeyText.opacity(0.8))
                            .kerning(1.12)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    // Install button or progress
                    if detector.isInstalling {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.vibeyBlue)

                            Text("Installing Claude Code CLI...")
                                .font(.atkinsonRegular(size: 16, comicSans: isComicSansMode))
                                .foregroundColor(.vibeyText.opacity(0.7))
                        }
                        .padding(32)
                    } else {
                        VStack(spacing: 16) {
                            // Install button
                            Button(action: {
                                detector.installClaudeCode()
                            }) {
                                HStack(spacing: 10) {
                                    Text("Install Claude Code")
                                        .font(.atkinsonRegular(size: 18, comicSans: isComicSansMode))
                                        .foregroundColor(.white)
                                        .kerning(1.26)

                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.vibeyBlue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            // Error message
                            if let error = detector.installError {
                                Text(error)
                                    .font(.atkinsonRegular(size: 14, comicSans: isComicSansMode))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }

                            // Manual install option
                            VStack(spacing: 8) {
                                Text("Or install manually:")
                                    .font(.atkinsonRegular(size: 14, comicSans: isComicSansMode))
                                    .foregroundColor(.vibeyText.opacity(0.6))

                                Text("npm install -g @anthropic-ai/claude-code")
                                    .font(.custom("SF Mono", size: 12))
                                    .foregroundColor(.vibeyBlue)
                                    .padding(8)
                                    .background(Color(hex: "1C1E22"))
                                    .cornerRadius(4)

                                Button(action: {
                                    // Recheck after manual install
                                    detector.checkInstallation()
                                }) {
                                    Text("I've installed it manually")
                                        .font(.atkinsonRegular(size: 14, comicSans: isComicSansMode))
                                        .foregroundColor(.vibeyBlue)
                                        .underline()
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 16)
                        }
                    }
                }
                .padding(64)
                .frame(width: 600)
                .background(Color.vibeyBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.vibeyCardBorder, lineWidth: 1)
                )

                Spacer()
            }
        }
        .onChange(of: detector.isInstalled) { newValue in
            if newValue {
                // Successfully installed!
                onComplete()
            }
        }
    }
}

#Preview {
    ClaudeCodeSetupView(
        detector: ClaudeCodeDetector(),
        onComplete: {}
    )
}
