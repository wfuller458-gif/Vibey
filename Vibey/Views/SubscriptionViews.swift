//
//  SubscriptionViews.swift
//  Vibey
//
//  License entry, paywall, and subscription management views
//

import SwiftUI

// MARK: - License Entry View

struct LicenseEntryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var licenseKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            // Background
            Color.vibeyBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Enter Your License Key")
                        .font(.lexendBold(size: 24))
                        .foregroundColor(.vibeyText)

                    Text("Check your email for your license key")
                        .font(.atkinsonRegular(size: 14))
                        .foregroundColor(.vibeyText.opacity(0.7))
                }

                // License key input
                VStack(spacing: 12) {
                    TextField("VIBEY-XXXX-XXXX-XXXX", text: $licenseKey)
                        .textFieldStyle(.plain)
                        .font(.custom("SF Mono", size: 16))
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color(hex: "1C1E22"))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.vibeyCardBorder, lineWidth: 1)
                        )
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            Task {
                                await validateAndActivate()
                            }
                        }

                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 12))
                            Text(error)
                                .font(.atkinsonRegular(size: 12))
                        }
                        .foregroundColor(.red)
                    }
                }

                // Activate button
                Button(action: {
                    Task {
                        await validateAndActivate()
                    }
                }) {
                    HStack(spacing: 8) {
                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }

                        Text(isValidating ? "Validating..." : "Activate License")
                            .font(.atkinsonRegular(size: 16))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(licenseKey.isEmpty ? Color.vibeyCardBorder : Color.vibeyBlue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isValidating || licenseKey.isEmpty)

                // Divider
                HStack {
                    Rectangle()
                        .fill(Color.vibeyCardBorder)
                        .frame(height: 1)

                    Text("or")
                        .font(.atkinsonRegular(size: 12))
                        .foregroundColor(.vibeyText.opacity(0.5))
                        .padding(.horizontal, 12)

                    Rectangle()
                        .fill(Color.vibeyCardBorder)
                        .frame(height: 1)
                }

                // Purchase button
                Button(action: {
                    appState.openSubscribePage()
                }) {
                    Text("Don't have a license? Purchase Now")
                        .font(.atkinsonRegular(size: 14))
                        .foregroundColor(.vibeyBlue)
                }
                .buttonStyle(.plain)
            }
            .padding(48)
            .frame(width: 500)
            .background(Color.vibeyBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.vibeyCardBorder, lineWidth: 1)
            )
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }

    func validateAndActivate() async {
        guard !licenseKey.isEmpty else { return }

        isValidating = true
        errorMessage = nil

        let success = await appState.activateLicense(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines))

        await MainActor.run {
            isValidating = false
            if success {
                dismiss()
            } else {
                errorMessage = "Invalid or expired license key"
            }
        }
    }
}

// MARK: - Paywall View

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingLicenseEntry = false

    var body: some View {
        ZStack {
            // Background
            Color.vibeyBackground
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                VStack(spacing: 12) {
                    if appState.subscriptionStatus == .expired {
                        if appState.trialEndDate != nil {
                            Text("Your Trial Has Ended")
                                .font(.lexendBold(size: 28))
                                .foregroundColor(.vibeyText)
                        } else {
                            Text("License Expired")
                                .font(.lexendBold(size: 28))
                                .foregroundColor(.vibeyText)
                        }
                    } else {
                        Text("Welcome to Vibey")
                            .font(.lexendBold(size: 28))
                            .foregroundColor(.vibeyText)
                    }

                    Text("Get lifetime access for a one-time purchase")
                        .font(.atkinsonRegular(size: 16))
                        .foregroundColor(.vibeyText.opacity(0.7))
                }

                // Lifetime price display
                VStack(spacing: 8) {
                    Text("$49.99")
                        .font(.lexendBold(size: 48))
                        .foregroundColor(.vibeyText)

                    Text("one-time payment")
                        .font(.atkinsonRegular(size: 14))
                        .foregroundColor(.vibeyText.opacity(0.6))
                }

                // Purchase button
                Button(action: {
                    appState.openSubscribePage()
                }) {
                    Text("Purchase Vibey")
                        .font(.atkinsonRegular(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.vibeyBlue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Already purchased
                Button(action: {
                    showingLicenseEntry = true
                }) {
                    Text("Already purchased? Enter license key")
                        .font(.atkinsonRegular(size: 14))
                        .foregroundColor(.vibeyBlue)
                }
                .buttonStyle(.plain)
            }
            .padding(48)
            .frame(width: 550)
            .background(Color.vibeyBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.vibeyCardBorder, lineWidth: 1)
            )
        }
        .sheet(isPresented: $showingLicenseEntry) {
            LicenseEntryView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Trial/Subscription Banner View

struct TrialBannerView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingLicenseEntry = false

    var trialProgress: Double {
        let total: Double = 7.0  // Each trial phase is 7 days
        let remaining = Double(appState.trialDaysRemaining)
        return remaining / total
    }

    var daysUntilRenewal: Int {
        guard let renewal = appState.renewalDate else { return 0 }
        let remaining = renewal.timeIntervalSince(Date())
        return max(0, Int(ceil(remaining / (24 * 60 * 60))))
    }

    var body: some View {
        if appState.subscriptionStatus == .trial {
            // Normal trial state
            VStack(spacing: 12) {
                HStack {
                    Text("Free trial")
                        .font(.atkinsonRegular(size: 16))
                        .foregroundColor(.vibeyText)

                    Spacer()

                    Text("\(appState.trialDaysRemaining) days left")
                        .font(.atkinsonRegular(size: 14))
                        .foregroundColor(.vibeyText.opacity(0.5))
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.vibeyText.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.vibeyBlue)
                            .frame(width: geometry.size.width * trialProgress, height: 6)
                    }
                }
                .frame(height: 6)

                Button(action: {
                    appState.openSubscribePage()
                }) {
                    Text("Upgrade")
                        .font(.atkinsonRegular(size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.vibeyBlue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    showingLicenseEntry = true
                }) {
                    Text("Enter License Key")
                        .font(.atkinsonRegular(size: 12))
                        .foregroundColor(.vibeyBlue)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(hex: "1C1E22"))
            .cornerRadius(8)
            .sheet(isPresented: $showingLicenseEntry) {
                LicenseEntryView()
                    .environmentObject(appState)
            }
        } else if appState.subscriptionStatus == .comicSansTrial {
            // Comic Sans trial - looks same as normal trial but fonts are Comic Sans
            VStack(spacing: 12) {
                HStack {
                    Text("Free trial")
                        .font(.custom("Comic Sans MS", size: 16))
                        .foregroundColor(.vibeyText)

                    Spacer()

                    Text("\(appState.trialDaysRemaining) days left")
                        .font(.custom("Comic Sans MS", size: 14))
                        .foregroundColor(.vibeyText.opacity(0.5))
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.vibeyText.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.vibeyBlue)
                            .frame(width: geometry.size.width * trialProgress, height: 6)
                    }
                }
                .frame(height: 6)

                Button(action: {
                    appState.openSubscribePage()
                }) {
                    Text("Upgrade")
                        .font(.custom("Comic Sans MS", size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.vibeyBlue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    showingLicenseEntry = true
                }) {
                    Text("Enter License Key")
                        .font(.custom("Comic Sans MS", size: 12))
                        .foregroundColor(.vibeyBlue)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(hex: "1C1E22"))
            .cornerRadius(8)
            .sheet(isPresented: $showingLicenseEntry) {
                LicenseEntryView()
                    .environmentObject(appState)
            }
        } else if appState.subscriptionStatus == .active {
            if appState.subscriptionPlan == .lifetime {
                // Gold Early Adopter badge
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Lifetime Member")
                            .font(.lexendBold(size: 14))
                            .foregroundColor(Color(hex: "FFD700"))

                        Spacer()
                    }

                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundColor(Color(hex: "1C1E22"))

                            Text("EARLY ADOPTER")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(Color(hex: "1C1E22"))

                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundColor(Color(hex: "1C1E22"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(4)

                        Spacer()
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "1C1E22"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(hex: "FFD700").opacity(0.6), Color(hex: "FFA500").opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
            } else {
                // Legacy subscription - active state
                VStack(alignment: .leading, spacing: 8) {
                    Text("Licensed")
                        .font(.atkinsonRegular(size: 16))
                        .foregroundColor(.vibeyText)

                    if daysUntilRenewal > 0 {
                        Text("Renews in \(daysUntilRenewal) days")
                            .font(.atkinsonRegular(size: 14))
                            .foregroundColor(.vibeyText.opacity(0.5))
                    }
                }
                .padding(12)
                .background(Color(hex: "1C1E22"))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Subscription Settings View

struct SubscriptionSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            Text("License")
                .font(.lexendBold(size: 20))
                .foregroundColor(.vibeyText)

            // Status card
            VStack(alignment: .leading, spacing: 16) {
                // Status badge
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusText)
                        .font(.atkinsonRegular(size: 14))
                        .foregroundColor(.vibeyText)
                }

                Divider()
                    .background(Color.vibeyCardBorder)

                // Plan details
                if appState.subscriptionStatus == .active || appState.subscriptionStatus == .cancelled {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Plan:")
                                .font(.atkinsonRegular(size: 13))
                                .foregroundColor(.vibeyText.opacity(0.6))

                            Spacer()

                            if let plan = appState.subscriptionPlan {
                                Text(plan == .lifetime ? "Lifetime" : plan == .monthly ? "Monthly" : "Yearly")
                                    .font(.lexendBold(size: 13))
                                    .foregroundColor(.vibeyText)
                            }
                        }

                        if appState.subscriptionPlan != .lifetime, let renewalDate = appState.renewalDate {
                            HStack {
                                Text(appState.subscriptionStatus == .cancelled ? "Expires:" : "Renews:")
                                    .font(.atkinsonRegular(size: 13))
                                    .foregroundColor(.vibeyText.opacity(0.6))

                                Spacer()

                                Text(renewalDate, style: .date)
                                    .font(.lexendBold(size: 13))
                                    .foregroundColor(.vibeyText)
                            }
                        }

                        if let key = appState.licenseKey {
                            HStack {
                                Text("License Key:")
                                    .font(.atkinsonRegular(size: 13))
                                    .foregroundColor(.vibeyText.opacity(0.6))

                                Spacer()

                                Text(key)
                                    .font(.custom("SF Mono", size: 11))
                                    .foregroundColor(.vibeyText)

                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(key, forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11))
                                        .foregroundColor(.vibeyBlue)
                                }
                                .buttonStyle(.plain)
                                .help("Copy")
                            }
                        }
                    }
                } else if appState.subscriptionStatus == .trial {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Trial ends:")
                                .font(.atkinsonRegular(size: 13))
                                .foregroundColor(.vibeyText.opacity(0.6))

                            Spacer()

                            if let trialEnd = appState.trialEndDate {
                                Text(trialEnd, style: .date)
                                    .font(.lexendBold(size: 13))
                                    .foregroundColor(.vibeyText)
                            }
                        }

                        Text("\(appState.trialDaysRemaining) days remaining")
                            .font(.atkinsonRegular(size: 12))
                            .foregroundColor(.vibeyBlue)
                    }
                }

                Divider()
                    .background(Color.vibeyCardBorder)

                // Actions
                VStack(spacing: 12) {
                    if appState.subscriptionStatus == .trial || appState.subscriptionStatus == .expired {
                        Button(action: {
                            appState.openSubscribePage()
                        }) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                Text("Purchase Vibey")
                                    .font(.atkinsonRegular(size: 14))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.vibeyBlue)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .background(Color(hex: "1C1E22"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.vibeyCardBorder, lineWidth: 1)
            )

            Spacer()
        }
        .padding(24)
        .frame(width: 400)
        .background(Color.vibeyBackground)
    }

    var statusColor: Color {
        switch appState.subscriptionStatus {
        case .trial:
            return .blue
        case .comicSansTrial:
            return .orange
        case .active:
            return .green
        case .paymentFailed:
            return .orange
        case .cancelled:
            return .yellow
        case .expired:
            return .red
        }
    }

    var statusText: String {
        switch appState.subscriptionStatus {
        case .trial:
            return "Free Trial Active"
        case .comicSansTrial:
            return "Comic Sans Mode Active"
        case .active:
            return appState.subscriptionPlan == .lifetime ? "Lifetime License" : "License Active"
        case .paymentFailed:
            return "Payment Issue"
        case .cancelled:
            return "Cancelled (Active until expiry)"
        case .expired:
            return "License Expired"
        }
    }
}

// MARK: - Comic Sans Warning Popup

struct ComicSansWarningPopup: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            // Popup card
            VStack(spacing: 24) {
                // Title
                Text("Free Trial Ended!")
                    .font(.custom("Comic Sans MS", size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(.vibeyText)
                    .multilineTextAlignment(.center)

                // Message
                VStack(spacing: 12) {
                    Text("You can keep using Vibey for another")
                        .font(.custom("Comic Sans MS", size: 16))
                        .foregroundColor(.vibeyText.opacity(0.8))

                    Text("\(appState.trialDaysRemaining) days")
                        .font(.custom("Comic Sans MS", size: 32))
                        .fontWeight(.bold)
                        .foregroundColor(.vibeyBlue)

                    Text("but everything will be in Comic Sans")
                        .font(.custom("Comic Sans MS", size: 16))
                        .foregroundColor(.vibeyText.opacity(0.8))
                }
                .multilineTextAlignment(.center)

                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        appState.openSubscribePage()
                    }) {
                        Text("Purchase to escape Comic Sans")
                            .font(.custom("Comic Sans MS", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.vibeyBlue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        isPresented = false
                    }) {
                        Text("I'll suffer through it")
                            .font(.custom("Comic Sans MS", size: 14))
                            .foregroundColor(.vibeyText.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
            .frame(width: 420)
            .background(Color(hex: "1C1E22"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.vibeyCardBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Trial Expired Popup

struct TrialExpiredPopup: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            // Popup card
            VStack(spacing: 24) {
                // Title
                Text("Free Trial Ended")
                    .font(.lexendBold(size: 28))
                    .foregroundColor(.vibeyText)
                    .multilineTextAlignment(.center)

                // Message
                VStack(spacing: 12) {
                    Text("Your free trial has ended.")
                        .font(.atkinsonRegular(size: 16))
                        .foregroundColor(.vibeyText.opacity(0.8))

                    Text("Purchase Vibey to continue")
                        .font(.atkinsonRegular(size: 16))
                        .foregroundColor(.vibeyText.opacity(0.8))
                }
                .multilineTextAlignment(.center)

                // Purchase button
                Button(action: {
                    appState.openSubscribePage()
                }) {
                    Text("Purchase Vibey")
                        .font(.atkinsonBold(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.vibeyBlue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .frame(width: 420)
            .background(Color(hex: "1C1E22"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.vibeyCardBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Subscription Expired Popup

struct SubscriptionExpiredPopup: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Dimmed background (no tap to dismiss)
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            // Popup card
            VStack(spacing: 24) {
                // Title
                Text("License Expired")
                    .font(.lexendBold(size: 28))
                    .foregroundColor(.vibeyText)
                    .multilineTextAlignment(.center)

                // Message
                VStack(spacing: 12) {
                    Text("Your license has expired.")
                        .font(.atkinsonRegular(size: 16))
                        .foregroundColor(.vibeyText.opacity(0.8))

                    Text("Please purchase Vibey to continue.")
                        .font(.atkinsonRegular(size: 16))
                        .foregroundColor(.vibeyText.opacity(0.8))
                }
                .multilineTextAlignment(.center)

                // Purchase button
                Button(action: {
                    appState.openSubscribePage()
                }) {
                    Text("Purchase Vibey")
                        .font(.atkinsonBold(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.vibeyBlue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .frame(width: 420)
            .background(Color(hex: "1C1E22"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.vibeyCardBorder, lineWidth: 1)
            )
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(AppState())
}
