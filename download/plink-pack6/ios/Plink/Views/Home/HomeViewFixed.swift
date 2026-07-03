import SwiftUI

// MARK: - HomeView (Pack 6: исправления UI)
// 1. Кнопки "Создать комнату" и "Присоединиться" — с надписями
// 2. Кнопка "Присоединиться" открывает Rooms tab + "Войти" subtab
// 3. Убрана шестерёнка с profile icon
// 4. Восстановлены "Смотрят сейчас" и рекомендации
// 5. Premium button — открывает PaywallView

struct HomeViewFixed: View {
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var showPaywall = false
    @State private var showCreateRoom = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero header
                heroSection
                
                // Action buttons (Pack 6: с надписями)
                actionButtons
                
                // "Смотрят сейчас" (Pack 6: восстановлено)
                watchingNowSection
                
                // Рекомендации (Pack 6: восстановлено)
                recommendationsSection
            }
            .padding()
        }
        .background(Color.plinkBgGradient)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showCreateRoom) {
            CreateRoomView()
        }
    }
    
    // MARK: - Hero
    
    private var heroSection: some View {
        VStack(spacing: 12) {
            Text("Plink")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.plinkGradient)
            
            Text("Смотрите вместе с друзьями")
                .font(.subheadline)
                .foregroundStyle(.plinkTextSecondary)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Action Buttons (Pack 6: с надписями)
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showCreateRoom = true
                HapticManager.shared.tap()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                    Text("Создать комнату")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.plinkGradient, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
            }
            .accessibleButton("Создать комнату", hint: "Открывает создание новой комнаты")
            
            Button {
                // Pack 6: переключиться на Rooms tab + "Войти" subtab
                tabRouter.switchToJoinRoom()
                HapticManager.shared.tap()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 32))
                    Text("Присоединиться")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.plinkWarmGradient, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
            }
            .accessibleButton("Присоединиться", hint: "Открывает вкладку Комнаты, раздел Войти")
        }
    }
    
    // MARK: - Watching Now (Pack 6: восстановлено)
    
    private var watchingNowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tv.fill")
                    .foregroundStyle(.plinkAccent)
                Text("Смотрят сейчас")
                    .font(.headline)
                Spacer()
            }
            
            // Список активных комнат
            ActiveRoomsList()
        }
    }
    
    // MARK: - Recommendations (Pack 6: восстановлено)
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.plinkSecondary)
                Text("Рекомендации")
                    .font(.headline)
                Spacer()
                
                Button {
                    showPaywall = true
                } label: {
                    Text("Plink+")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.plinkRainbow, in: Capsule())
                        .foregroundStyle(.white)
                }
                .accessibleButton("Plink Plus Premium", hint: "Открывает премиум подписку")
            }
            
            RecommendationsList()
        }
    }
}

// MARK: - TabRouter (Pack 6: для переключения на Rooms/Join)

@MainActor
final class TabRouter: ObservableObject {
    static let shared = TabRouter()
    
    enum Tab: Int {
        case home = 0
        case rooms = 1
        case friends = 2
        case profile = 3
    }
    
    @Published var selectedTab: Tab = .home
    @Published var roomsSubTab: RoomsSubTab = .myRooms
    
    enum RoomsSubTab: String, CaseIterable {
        case myRooms = "Мои"
        case join = "Войти"
        case requests = "Запросы"
    }
    
    func switchToJoinRoom() {
        selectedTab = .rooms
        roomsSubTab = .join
    }
    
    func switchToCreateRoom() {
        selectedTab = .rooms
        roomsSubTab = .myRooms
    }
}

// MARK: - Stubs (replace with real views)

private struct ActiveRoomsList: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<3) { _ in
                HStack {
                    Circle().fill(.plinkPrimary.opacity(0.3)).frame(width: 40, height: 40)
                    VStack(alignment: .leading) {
                        Text("Lofi beats 🎵").font(.subheadline.bold())
                        Text("5 участников • YouTube").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("AB12CD").font(.caption.monospaced())
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct RecommendationsList: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<5) { _ in
                    VStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.plinkGradient)
                            .frame(width: 140, height: 80)
                        Text("The Office").font(.caption.bold())
                        Text("Comedy").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(width: 140)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HomeViewFixed()
        .environmentObject(TabRouter.shared)
}
