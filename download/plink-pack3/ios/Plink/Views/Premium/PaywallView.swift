import SwiftUI
import StoreKit

// MARK: - PaywallView (Pack 3: Premium Subscription)
/// Красивый Paywall с StoreKit 2 purchases.

struct PaywallView: View {
    @StateObject private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.linearGradient(
                                colors: [.purple, .pink, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        
                        Text("Plink Premium")
                            .font(.largeTitle.bold())
                        
                        Text("Открой все возможности Plink")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "infinity", title: "Безлимит комнат", subtitle: "Создавай сколько хочешь")
                        FeatureRow(icon: "person.2.fill", title: "До 20 участников", subtitle: "Вместо 10 в бесплатной")
                        FeatureRow(icon: "video.slash.fill", title: "Без рекламы", subtitle: "Никаких прероллов")
                        FeatureRow(icon: "paintpalette.fill", title: "Эксклюзивные темы", subtitle: "5 премиум-тем оформления")
                        FeatureRow(icon: "bolt.fill", title: "Приоритетная поддержка", subtitle: "Ответ в течение часа")
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    
                    // Plans
                    VStack(spacing: 12) {
                        ForEach(store.products, id: \.id) { product in
                            PlanCard(
                                product: product,
                                isSelected: selectedProduct?.id == product.id,
                                isPopular: product.id == StoreManager.ProductID.yearly
                            ) {
                                selectedProduct = product
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // CTA Button
                    Button {
                        purchase()
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(selectedProduct == nil 
                                     ? "Выберите план"
                                     : "Купить за \(selectedProduct!.displayPrice)")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            selectedProduct == nil
                            ? Color.gray.opacity(0.3)
                            : Color.purple
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(selectedProduct == nil || isPurchasing)
                    .padding(.horizontal)
                    
                    // Restore
                    Button("Восстановить покупки") {
                        Task { try? await store.restorePurchases() }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    
                    // Terms
                    VStack(spacing: 4) {
                        Text("Оплата спишется с вашего Apple ID при подтверждении покупки.")
                        Text("Подписка автоматически продлевается, если не отменена за 24 часа до конца периода.")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func purchase() {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        
        Task {
            do {
                try await store.purchase(product)
                await MainActor.run {
                    isPurchasing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 32, height: 32)
                .foregroundStyle(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let isPopular: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                        if isPopular {
                            Text("ПОПУЛЯРНЫЙ")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.orange, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.title3.bold())
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .purple : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.purple : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
