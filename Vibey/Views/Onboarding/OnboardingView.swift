//
//  OnboardingView.swift
//  Vibey
//
//  Main onboarding flow - just first project creation
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        FirstProjectView(onComplete: {
            // Onboarding complete! Go straight to main app
            appState.completeOnboarding()
        })
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
