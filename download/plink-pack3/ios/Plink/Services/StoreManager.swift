import Foundation
import StoreKit

// MARK: - StoreManager (Pack 3: StoreKit 2 Premium)
/// Полная реализация In-App Purchases через StoreKit 2.
/// Поддерживает:
/// - Monthly / Yearly / Lifetime premium
/// - Server-side receipt validation
/// - Restore purchases
/// - Subscription status sync

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProducts: Set<Product.ID> = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    
    // Product IDs (должны совпадать с App Store Connect)
    enum ProductID {
        static let monthly = "plink.premium.monthly"
        static let yearly = "plink.premium.yearly"
        static let lifetime = "plink.premium.lifetime"
    }
    
    private let apiBaseURL = URL(string: "https://plink-backend-production-ef31.up.railway.app/api")!
    private var transactionListener: Task<Void, Error>?
    
    private init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let productIDs: Set<String> = [
                ProductID.monthly,
                ProductID.yearly,
                ProductID.lifetime,
            ]
            
            products = try await Product.products(for: productIDs)
            print("✅ Loaded \(products.count) products")
        } catch {
            lastError = "Failed to load products: \(error.localizedDescription)"
            print("❌ StoreKit error: \(error)")
        }
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Send receipt to backend for verification
            try await verifyReceiptWithBackend(transaction: transaction, product: product)
            
            await transaction.finish()
            await updatePurchasedProducts()
            
        case .userCancelled:
            print("User cancelled purchase")
        case .pending:
            print("Purchase pending (ask parent, etc.)")
        @unknown default:
            throw StoreError.unknownResult
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
        
        // Sync с бэкендом
        for productID in purchasedProducts {
            if let product = products.first(where: { $0.id == productID }) {
                try? await verifyReceiptWithBackend(transaction: nil, product: product)
            }
        }
    }
    
    // MARK: - Verify with Backend
    
    private func verifyReceiptWithBackend(transaction: Transaction?, product: Product) async throws {
        guard let authToken = AuthService.shared.api.authToken else {
            throw StoreError.notAuthenticated
        }
        
        // Get receipt data from StoreKit 2
        let receiptURL = Bundle.main.appStoreReceiptURL
        guard let receiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            throw StoreError.noReceipt
        }
        
        let receiptBase64 = receiptData.base64EncodedString()
        
        var request = URLRequest(url: apiBaseURL.appendingPathComponent("billing/verify"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "receipt": receiptBase64,
            "productId": product.id,
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            throw StoreError.verificationFailed
        }
        
        // Update local user state
        if let payload = try? JSONDecoder().decode(VerifyResponse.self, from: data) {
            await MainActor.run {
                AuthService.shared.currentUser?.isPremium = payload.premium
                AuthService.shared.currentUser?.premiumUntil = payload.premiumUntil
            }
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Check Verified
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Update Purchased Products
    
    private func updatePurchasedProducts() async {
        var purchased: Set<Product.ID> = []
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchased.insert(transaction.productID)
            }
        }
        
        await MainActor.run {
            self.purchasedProducts = purchased
        }
    }
    
    // MARK: - Premium Status
    
    var isPremium: Bool {
        !purchasedProducts.isEmpty
    }
    
    func premiumStatus() async -> (isPremium: Bool, expiresAt: Date?) {
        guard let authToken = AuthService.shared.api.authToken else {
            return (false, nil)
        }
        
        do {
            var request = URLRequest(url: apiBaseURL.appendingPathComponent("billing/status"))
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let status = try JSONDecoder().decode(BillingStatus.self, from: data)
            
            let formatter = ISO8601DateFormatter()
            let expiresAt = status.premiumUntil.flatMap { formatter.date(from: $0) }
            
            return (status.isPremium, expiresAt)
        } catch {
            return (false, nil)
        }
    }
}

// MARK: - Response Models

private struct VerifyResponse: Codable {
    let valid: Bool
    let premium: Bool
    let premiumUntil: String?
    let plan: String?
}

private struct BillingStatus: Codable {
    let isPremium: Bool
    let premiumUntil: String?
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case noReceipt
    case verificationFailed
    case notAuthenticated
    case unknownResult
    
    var errorDescription: String? {
        switch self {
        case .noReceipt: return "Receipt not found"
        case .verificationFailed: return "Receipt verification failed"
        case .notAuthenticated: return "Not authenticated"
        case .unknownResult: return "Unknown purchase result"
        }
    }
}
