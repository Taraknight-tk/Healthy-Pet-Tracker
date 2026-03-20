//
//  StoreService.swift
//  Pet Weight Tracker
//

import Foundation
import StoreKit
import Combine

/// Manages StoreKit products and purchases
@MainActor
class StoreService: ObservableObject {
    static let shared = StoreService()
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var productsLoadFailed: Bool = false
    
    // Matches the Non-Consumable product created in App Store Connect
    private let productIDs = [
        "com.taraknight.Healthy_Pet_Tracker.pro"
    ]
    
    enum PurchaseState {
        case idle
        case purchasing
        case success
        case failed(Error)
    }
    
    private init() {}
    
    /// Load products from the App Store (or local StoreKit config in debug).
    /// Retries up to 3 times with a short delay because the local StoreKit
    /// service can return empty on the first call while it initialises.
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        productsLoadFailed = false

        for attempt in 1...3 {
            do {
                let loaded = try await Product.products(for: productIDs)
                if !loaded.isEmpty {
                    products = loaded
                    isLoadingProducts = false
                    return
                }
                print("StoreKit returned no products on attempt \(attempt) — retrying…")
            } catch {
                print("StoreKit load error on attempt \(attempt): \(error)")
            }
            if attempt < 3 {
                try? await Task.sleep(for: .seconds(1))
            }
        }

        isLoadingProducts = false
        productsLoadFailed = true
        print("StoreKit: could not load products after 3 attempts.")
    }
    
    /// Purchase a product
    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                switch verification {
                case .verified(let transaction):
                    // Transaction is verified, grant access
                    await EntitlementService.shared.checkEntitlement()
                    await transaction.finish()
                    purchaseState = .success
                    
                case .unverified(let transaction, let error):
                    // Transaction failed verification
                    await transaction.finish()
                    purchaseState = .failed(error)
                }
                
            case .userCancelled:
                purchaseState = .idle
                
            case .pending:
                // Purchase is pending (e.g., Ask to Buy)
                purchaseState = .idle
                
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error)
        }
    }
}
