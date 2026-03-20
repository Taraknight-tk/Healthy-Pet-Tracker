//
//  UpgradeView.swift
//  Healthy Pet Tracker
//
//  Paywall presented whenever a free user taps a locked Pro feature.
//  Requires EntitlementService and StoreService in the environment
//  (both are injected at the WindowGroup level in PetWeightTrackerApp).
//

import SwiftUI
import StoreKit

struct UpgradeView: View {
    @EnvironmentObject var store: StoreService
    @EnvironmentObject var entitlements: EntitlementService
    @Environment(\.dismiss) private var dismiss

    // MARK: - Feature list

    private struct ProFeature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
    }

    private let features: [ProFeature] = [
        ProFeature(icon: "photo.fill",
                   title: "Custom Pet Photo",
                   description: "Add a personal photo to each pet's profile"),
        ProFeature(icon: "photo.on.rectangle.fill",
                   title: "Photo per Log Entry",
                   description: "Attach a photo to each weight log"),
        ProFeature(icon: "bell.badge.fill",
                   title: "Training Reminders",
                   description: "Daily check-in and weight logging reminders"),
        ProFeature(icon: "calendar.badge.clock",
                   title: "Vet Appointment Alerts",
                   description: "Never miss a vet appointment"),
        ProFeature(icon: "list.bullet.clipboard.fill",
                   title: "Breed-Specific Insights",
                   description: "Healthy weight ranges and health notes for your breed"),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    featuresSection
                    purchaseSection
                }
                .padding()
            }
            .background(Color.bgPrimary)
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgSecondary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                        .tint(.textSecondary)
                }
            }
        }
        .task { await store.loadProducts() }
        // Auto-dismiss when the purchase completes and entitlement flips to true
        .onChange(of: entitlements.hasPremium) { _, isPro in
            if isPro { dismiss() }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentPrimary)
                .accessibilityHidden(true)

            Text("Healthy Pet Tracker Pro")
                .font(.title2)
                .fontWeight(.bold)
                .primaryText()

            Text("One-time purchase. No subscription. No ads.\nAll your pet's data stays private on your device.")
                .font(.subheadline)
                .secondaryText()
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                HStack(spacing: 16) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.accentPrimary)
                        .frame(width: 32)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .primaryText()
                        Text(feature.description)
                            .font(.caption)
                            .secondaryText()
                    }

                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                if index < features.count - 1 {
                    Divider()
                        .padding(.leading, 64)
                }
            }
        }
        .background(Color.bgTertiary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if let product = store.products.first {
                // Products loaded — show purchase button
                Button {
                    Task { await store.purchase(product) }
                } label: {
                    Group {
                        if isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text("Unlock Pro — \(product.displayPrice)")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentPrimary)
                    .cornerRadius(12)
                }
                .disabled(isPurchasing)

            } else if store.productsLoadFailed {
                // Load failed — show a retry button so the user isn't stuck
                VStack(spacing: 8) {
                    Text("Couldn't load pricing information.")
                        .font(.subheadline)
                        .secondaryText()
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await store.loadProducts() }
                    } label: {
                        Text("Try Again")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentPrimary)
                            .cornerRadius(12)
                    }
                }

            } else {
                // Still loading — show a spinner, never an indefinite disabled button
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("Loading…")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentMuted)
                .cornerRadius(12)
            }

            Button {
                Task {
                    try? await entitlements.restorePurchases()
                }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .secondaryText()
            }

            Text("Payment charged to your Apple ID account at confirmation. This is a one-time purchase — not a subscription.")
                .font(.caption2)
                .tertiaryText()
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private var isPurchasing: Bool {
        if case .purchasing = store.purchaseState { return true }
        return false
    }
}

#Preview {
    UpgradeView()
        .environmentObject(EntitlementService.shared)
        .environmentObject(StoreService.shared)
}
