//
//  PaywallView.swift
//  Vibey
//
//  Subscription paywall screen
//  Shows pricing: £5.99/month or £39.99/year with 7-day free trial
//  TODO: Integrate RevenueCat + StoreKit 2
//

import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background
            Color.vibeyBackground
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 64) {
                VibeyLogo()

                VStack(spacing: 32) {
                    // Heading
                    VStack(spacing: 16) {
                        Text("Start Your Free Trial")
                            .font(.atkinsonBold(size: 32))
                            .foregroundColor(.vibeyText)

                        Text("7 days free, then choose your plan")
                            .font(.atkinsonRegular(size: 18))
                            .foregroundColor(.vibeyText.opacity(0.7))
                    }

                    // Pricing options
                    VStack(spacing: 16) {
                        // Monthly plan
                        PricingCard(
                            title: "Monthly",
                            price: "£5.99",
                            period: "per month",
                            isRecommended: false
                        )

                        // Annual plan
                        PricingCard(
                            title: "Annual",
                            price: "£39.99",
                            period: "per year",
                            savings: "Save 44%",
                            isRecommended: true
                        )
                    }

                    // Start trial button
                    Button(action: {
                        // TODO: Initiate RevenueCat subscription
                        onComplete()
                    }) {
                        Text("Start Free Trial")
                            .font(.atkinsonBold(size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.vibeyBlue)
                            .cornerRadius(CornerRadius.button)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 400)

                    // Fine print
                    Text("Free for 7 days, then your selected plan begins. Cancel anytime.")
                        .font(.atkinsonRegular(size: 12))
                        .foregroundColor(.vibeyText.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .frame(width: 400)
                }
            }
        }
    }
}

// Pricing card component
struct PricingCard: View {
    let title: String
    let price: String
    let period: String
    var savings: String? = nil
    let isRecommended: Bool

    var body: some View {
        VStack(spacing: 12) {
            if isRecommended {
                Text("RECOMMENDED")
                    .font(.lexendBold(size: 10))
                    .foregroundColor(.vibeyBlue)
                    .kerning(1)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.atkinsonBold(size: 20))
                        .foregroundColor(.vibeyText)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(price)
                            .font(.atkinsonBold(size: 28))
                            .foregroundColor(.vibeyText)

                        Text(period)
                            .font(.atkinsonRegular(size: 14))
                            .foregroundColor(.vibeyText.opacity(0.7))
                    }
                }

                Spacer()

                if let savings = savings {
                    Text(savings)
                        .font(.lexendBold(size: 12))
                        .foregroundColor(.vibeyBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.vibeyBlue.opacity(0.15))
                        .cornerRadius(100)
                }
            }
            .padding(24)
            .background(Color.vibeyCardBorder)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isRecommended ? Color.vibeyBlue : Color.clear, lineWidth: 2)
            )
        }
        .frame(width: 400)
    }
}

#Preview {
    PaywallView(onComplete: {})
        .environmentObject(AppState())
}
