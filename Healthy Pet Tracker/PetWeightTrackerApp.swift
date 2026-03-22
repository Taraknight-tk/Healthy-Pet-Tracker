//
//  PetWeightTrackerApp.swift
//  Pet Weight Tracker
//

import SwiftUI
import SwiftData
import StoreKit

@main
struct PetWeightTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private var transactionListener: Task<Void, Error>?
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Pet.self,
            WeightEntry.self,
            PetNote.self,
            PetDocument.self,
            PetReminder.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Start listening for background transactions (cross-device purchases,
        // Ask to Buy approvals, renewals) the moment the app launches.
        transactionListener = listenForTransactions()
        // Configure navigation bar appearance once at app launch
        configureNavigationBarAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Load products and check entitlement on every cold launch
                    // so prices are ready before the paywall ever appears.
                    async let products: () = StoreService.shared.loadProducts()
                    async let entitlement: () = EntitlementService.shared.checkEntitlement()
                    _ = await (products, entitlement)
                }
        }
        .modelContainer(sharedModelContainer)
        .environmentObject(EntitlementService.shared)
        .environmentObject(StoreService.shared)
        // Custom-interval reminders use one-shot triggers (so they fire at the
        // correct time of day). When the app comes to the foreground, we check
        // whether each custom-interval notification has already delivered and,
        // if so, queue the next occurrence — keeping the reminder chain alive.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { @MainActor in
                let context = sharedModelContainer.mainContext
                let pets = (try? context.fetch(FetchDescriptor<Pet>())) ?? []
                for pet in pets {
                    for reminder in pet.reminders {
                        NotificationService.shared.rescheduleCustomIfExpired(reminder)
                    }
                }
            }
        }
    }
    
    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.bgSecondary)
        
        // Set title text color
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.textPrimary)
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.textPrimary)
        ]
        
        // Apply globally
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    // MARK: - Transaction Listener

    /// Listens for background transactions (renewals, cross-device purchases,
    /// Ask to Buy approvals). Must be started at launch and held in a Task property
    /// so it is never cancelled.
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await EntitlementService.shared.checkEntitlement()
                    await transaction.finish()
                }
            }
        }
    }
}
