//
//  EntitlementService.swift
//  Pet Weight Tracker
//

import Foundation
import StoreKit
import Combine

/// Manages user entitlements and purchase verification
@MainActor
class EntitlementService: ObservableObject {
    static let shared = EntitlementService()
    
    @Published private(set) var hasPremium: Bool = false
    
    private init() {}
    
    /// Check current entitlement status based on StoreKit transactions
    func checkEntitlement() async {
        var isPremium = false
        
        // Iterate through all verified transactions
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // Check if this is the pro version purchase
                if transaction.productID == "com.taraknight.Healthy_Pet_Tracker.pro" {
                    isPremium = true
                    break
                }
            }
        }
        
        hasPremium = isPremium
    }
    
    /// Restore purchases - useful for "Restore Purchases" button
    func restorePurchases() async throws {
        try await AppStore.sync()
        await checkEntitlement()
    }
}
