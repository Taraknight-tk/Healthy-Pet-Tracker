// StoreService.swift
// Healthy Pet Tracker
//
// Handles product fetching and purchase initiation.
// Delegates entitlement state to EntitlementService after a successful purchase.
//
// Usage:
//   @EnvironmentObject var store: StoreService
//   try await store.purchase(store.proProduct!)

import StoreKit
import Foundation

@MainActor
final class StoreService: ObservableObject {

    // MARK: - Shared Instance

    static let shared = StoreService()

    // MARK: - Published State

    /// Available products fetched from App Store Connect (or .storekit config in sandbox).
    @Published private(set) var products: [Product] = []

    /// True while a purchase is in flight — use to show loading UI and prevent double-taps.
    @Published private(set) var isPurchasing: Bool = false

    /// Set if a purchase or product load fails. Display to the user in UpgradeView.
    @Published var purchaseError: String?

    // MARK: - Constants

    private let productIDs: Set<String> = [
        "com.taraknight.Healthy_Pet_Tracker.pro"
    ]

    // MARK: - Computed Helpers

    /// The Pro product, once loaded. Nil only during initial load or if App Store is unreachable.
    var proProduct: Product? {
        products.first(where: { $0.id == "com.taraknight.Healthy_Pet_Tracker.pro" })
    }

    // MARK: - Init

    private init() {
        Task { await loadProducts() }
    }

    // MARK: - Product Loading

    /// Fetches product metadata from App Store Connect.
    /// In sandbox, reads from StoreKitConfig.storekit configuration file.
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            purchaseError = "Unable to load purchase options. Please check your connection and try again."
            print("StoreService: Product load failed — \(error)")
        }
    }

    // MARK: - Purchase

    /// Initiates a purchase for the given product.
    /// - Returns: The verified transaction on success, or nil if the user cancelled / purchase is pending.
    /// - Throws: `StoreServiceError.failedVerification` if StoreKit cannot verify the transaction.
    @discardableResult
    func purchase(_ product: Product) async throws -> Transaction? {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verificationResult):
            guard case .verified(let transaction) = verificationResult else {
                throw StoreServiceError.failedVerification
            }
            // Update entitlement state before finishing the transaction.
            await EntitlementService.shared.checkEntitlement()
            await transaction.finish()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            // Ask to Buy or payment method issue — entitlement will arrive via Transaction.updates listener.
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore Purchases

    /// Syncs the App Store receipt and refreshes entitlement state.
    /// Required by Apple review guidelines. Show a "Restore Purchases" button in UpgradeView.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await EntitlementService.shared.checkEntitlement()
        } catch {
            purchaseError = "Restore failed. If you previously purchased Pro, please contact support."
            print("StoreService: Restore failed — \(error)")
        }
    }
}

// MARK: - Errors

enum StoreServiceError: Error, LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Purchase verification failed. Please try again or contact support."
        }
    }
}
