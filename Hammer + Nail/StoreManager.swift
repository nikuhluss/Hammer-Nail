import StoreKit
import Combine // Needed for @Published
import UIKit // Needed for UIColor

// --- Define Product IDs ---
// IMPORTANT: Replace these with your actual Product IDs from App Store Connect / .storekit file
enum ProductIDs {
    static let teal = "ht1"
    static let orange = "ho1"
    static let purple = "hp1"
    static let yellow = "hy1"
    static let darkBlue = "hdb1"
    static let watermelon = "hw1"
    static let brightSky = "hbs1"
    static let softGray = "hsg1"
}

let shopColorMap: [String: UIColor] = [
    ProductIDs.teal: UIColor(red: 0.1, green: 0.7, blue: 0.6, alpha: 1.0),       // Teal
    ProductIDs.orange: UIColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1.0),     // Orange
    ProductIDs.purple: UIColor(red: 0.4, green: 0.3, blue: 0.7, alpha: 1.0),     // Purple
    ProductIDs.yellow: UIColor(red: 1.0, green: 0.9, blue: 0.1, alpha: 1.0),     // Yellow
    ProductIDs.darkBlue: UIColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 1.0),   // Dark Blue
    ProductIDs.watermelon: UIColor(red: 0.9, green: 0.3, blue: 0.4, alpha: 1.0), // Watermelon
    ProductIDs.brightSky: UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0),   // Bright Sky
    ProductIDs.softGray: UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)     // Soft Gray
]


class StoreManager: ObservableObject {

    @Published var availableProducts: [Product] = [] // Products fetched from App Store Connect / .storekit file
    @Published var purchasedProductIDs: Set<String> = [] // IDs of products the user owns

    private var productsLoaded = false
    private var updates: Task<Void, Never>? = nil // Task to monitor transactions

    // IMPORTANT: List ALL product IDs you want to fetch from the store
    private let productIdsToLoad: [String] = Array(shopColorMap.keys) // Use keys from shopColorMap

    private let purchasedIDsKey = "purchasedProductIDs" // Key for UserDefaults

    init() {
        // Start listening for transaction updates
        updates = observeTransactionUpdates()
        
        // Load saved purchases
        loadPurchasedIDs()
        
        // Print initial state for debugging
        print("Initializing StoreManager with product IDs: \(productIdsToLoad)")
        
        // Fetch products immediately
        Task {
            await requestProducts()
        }
    }

    deinit {
        updates?.cancel() // Stop listening when the object is deallocated
        print("StoreManager deinitialized.")
    }

    // In StoreManager.swift
    @MainActor // Ensure UI updates happen on the main thread
    func requestProducts() async {
        guard !productsLoaded else {
            print("Products already loaded")
            return
        }
        
        print("Requesting products with IDs: \(productIdsToLoad)")
        
        guard !productIdsToLoad.isEmpty else {
            print("Error: No product IDs to load")
            return
        }
        
        do {
            let storeProducts = try await Product.products(for: productIdsToLoad)
            print("Successfully loaded \(storeProducts.count) products")
            
            if storeProducts.isEmpty {
                print("Warning: Store products array is empty")
            } else {
                for product in storeProducts {
                    print("Loaded product: \(product.id) - \(product.displayName)")
                }
            }
            
            availableProducts = storeProducts
            productsLoaded = true
            await updatePurchasedStatus()
        } catch {
            productsLoaded = false
            print("Failed to fetch products: \(error)")
            print("Localized error: \(error.localizedDescription)")
        }
    }

    // --- Purchase Handling ---
    @MainActor
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        print("Initiating purchase for \(product.id)")
        let result = try await product.purchase()

        switch result {
        case .success(let verificationResult):
            // Verify the transaction (important!)
            switch verificationResult {
            case .verified(let transaction):
                print("Purchase successful and verified for \(transaction.productID)")
                // Add to purchased set and save
                purchasedProductIDs.insert(transaction.productID)
                savePurchasedIDs()
                // MUST Finish the transaction
                await transaction.finish()
                print("Transaction finished for \(transaction.productID)")
                return transaction
            case .unverified(let transaction, let error):
                // Do NOT unlock content for unverified transactions
                print("Purchase failed verification for \(transaction.productID): \(error)")
                throw StoreKitError.systemError(error) // Or a custom error
            }
        case .userCancelled:
            print("User cancelled purchase for \(product.id)")
            return nil // Indicate cancellation, not an error
        case .pending:
            print("Purchase pending for \(product.id)...")
            // Handle pending state appropriately in UI (e.g., show a message)
            return nil // Indicate pending state
        @unknown default:
            print("Unknown purchase result for \(product.id)")
            return nil // Indicate an unexpected state
        }
    }

    // --- Transaction Observation ---
    // Listens for transactions coming in while the app is running
    // (e.g., purchases made on another device, renewals, refunds)
    func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [unowned self] in // Use unowned self carefully
            for await verificationResult in Transaction.updates {
                // Handle transaction updates
                switch verificationResult {
                case .verified(let transaction):
                    print("Transaction update received: \(transaction.productID), Revoked: \(transaction.revocationDate != nil)")
                    // Update purchase status based on the transaction state
                    await MainActor.run { // Ensure UI-related updates are on main thread
                        if transaction.revocationDate == nil { // Not revoked
                            self.purchasedProductIDs.insert(transaction.productID)
                        } else {
                            self.purchasedProductIDs.remove(transaction.productID)
                        }
                        self.savePurchasedIDs()
                    }
                    // Always finish the transaction after handling it
                    await transaction.finish()
                    print("Finished handling transaction update for \(transaction.productID)")
                case .unverified(let transaction, let error):
                    // Log or handle potentially fraudulent transactions
                    print("Unverified transaction update received for \(transaction.productID): \(error)")
                }
            }
        }
    }

    // --- Check Current Entitlements ---
    // Checks the user's current purchases (non-consumables, active subscriptions)
    // Should be called on app launch and potentially periodically or when app comes to foreground
    @MainActor
    func updatePurchasedStatus() async {
        print("Updating purchased status...")
        var currentPurchasedIDs = Set<String>()
        // Iterate through all products the user currently owns
        for await result in Transaction.currentEntitlements {
             if case .verified(let transaction) = result {
                // Check if the purchase is valid (non-consumable or active subscription)
                 if transaction.productType == .nonConsumable && transaction.revocationDate == nil {
                     currentPurchasedIDs.insert(transaction.productID)
                     print("Found owned non-consumable: \(transaction.productID)")
                 }
                 // Add checks here for subscriptions if you add them later
             }
        }

        // Only update if the set has actually changed to avoid unnecessary UI reloads
        if self.purchasedProductIDs != currentPurchasedIDs {
            self.purchasedProductIDs = currentPurchasedIDs
            savePurchasedIDs() // Save the latest status
            print("Purchased status updated. Items owned: \(self.purchasedProductIDs.count)")
            // Post a notification or use Combine to let GameViewController know data changed
            NotificationCenter.default.post(name: .purchasesUpdated, object: nil)
        } else {
            print("Purchased status checked, no changes detected.")
        }
    }

    // --- Persistence (using UserDefaults) ---
    private func savePurchasedIDs() {
        UserDefaults.standard.set(Array(purchasedProductIDs), forKey: purchasedIDsKey)
        // print("Saved purchased IDs: \(Array(purchasedProductIDs))") // Can be noisy, enable for debugging
    }

    private func loadPurchasedIDs() {
        if let savedIDs = UserDefaults.standard.array(forKey: purchasedIDsKey) as? [String] {
            purchasedProductIDs = Set(savedIDs)
            print("Loaded purchased IDs from UserDefaults: \(purchasedProductIDs.count)")
        } else {
             print("No purchased IDs found in UserDefaults.")
             purchasedProductIDs = Set<String>() // Ensure it's initialized
        }
    }

    // --- Helper ---
    func isPurchased(_ productID: String) -> Bool {
        return purchasedProductIDs.contains(productID)
    }
}

// Notification name for purchase updates
extension Notification.Name {
    static let purchasesUpdated = Notification.Name("purchasesUpdatedNotification")
}
