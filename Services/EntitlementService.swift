// EntitlementService.swift
// Healthy Pet Tracker
//
// Single source of truth for whether the user has an active Pro entitlement.
// Uses StoreKit 2 — all verification is on-device, no server needed.
//
// Usage:
//   @EnvironmentObject var entitlements: EntitlementService
//   if entitlements.isPro { ... }

import StoreKit
import Foundation

@MainActor
final class EntitlementService: ObservableObject {

    // MARK: - Shared Instance

    static let shared = EntitlementService()

    // MARK: - Published State

    /// True when the user has a verified, non-revoked Pro purchase.
    @Published private(set) var isPro: Bool = false

    /// True while the entitlement check is in flight (e.g., on first launch).
    @Published private(set) var isLoading: Bool = false

    // MARK: - Constants

    private let productID = "com.taraknight.Healthy_Pet_Tracker.pro"

    // MARK: - Init

    private init() {}

    // MARK: - Entitlement Check

    /// Iterates StoreKit 2 currentEntitlements to determine Pro status.
    /// Call this on app launch and after any purchase or restore.
    func checkEntitlement() async {
        isLoading = true
        defer { isLoading = false }

        var foundValidEntitlement = false

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == productID,
                   transaction.revocationDate == nil {
                    foundValidEntitlement = true
                }
            case .unverified:
                // Verification failed — treat as no entitlement.
                // StoreKit 2 handles this cryptographically; no custom logic needed.
                break
            }
        }

        isPro = foundValidEntitlement
    }
}
