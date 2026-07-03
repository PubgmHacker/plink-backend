import SwiftUI

// MARK: - HomeView (Pack 6.1: развёрнутые кнопки по умолчанию)
// Кнопки "Создать комнату" и "Присоединиться":
// - Изначально развёрнуты (с надписями)
// - Через 6 сек бездействия сворачиваются в иконки
// - При тапе разворачиваются обратно + сброс таймера
// - При скролле/любом тапе сбрасывают таймер

struct HomeViewFixed: View {
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var showPaywall = false
    @State private var showCreateRoom = false
    
    // Pack 6.1: состояние развёрнутости кнопок
    @State private var buttonsExpanded: Bool = true
    @State private var collapseTask: Task<Void, Never>?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                actionButtons
                watchingNowSection
                recommendationsSection
            }
            .padding()
        }
        .background(Color.plinkBgGradient)
        // Pack 6.1: любой тап сбрасывает таймер сворачивания
        .onTapGesture { resetCollapseTimer() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showCreateRoom) { CreateRoomView() }
        .task {
            // Pack 6.1: запустить таймер при первом появлении
            startCollapseTimer()
        }
        .onDisappear {
            collapseTask?.cancel()
        }
    }
    
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
    
    // MARK: - Action Buttons (Pack 6.1: expand/collapse)
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showCreateRoom = true
                HapticManager.shared.tap()
                resetCollapseTimer()
            } label: {
                ActionButton(
                    icon: "plus.circle.fill",
                    title: "Создать комнату",
                    isExpanded: buttonsExpanded,
                    gradient: Color.plinkGradient
                )
            }
            .accessibleButton("Создать комнату", hint: "Открывает создание новой комнаты")
            
            Button {
                tabRouter.switchToJoinRoom()
                HapticManager.shared.tap()
                resetCollapseTimer()
            } label: {
                ActionButton(
                    icon: "arrow.right.circle.fill",
                    title: "Присоединиться",
                    isExpanded: buttonsExpanded,
                    gradient: Color.plinkWarmGradient
                )
            }
            .accessibleButton("Присоединиться", hint: "Открывает вкладку Комнаты, раздел Войти")
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: buttonsExpanded)
    }
    
    // MARK: - Sections
    
    private var watchingNowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tv.fill").foregroundStyle(.plinkAccent)
                Text("Смотрят сейчас").font(.headline)
                Spacer()
            }
            ActiveRoomsList()
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(.plinkSecondary)
                Text("Рекомендации").font(.headline)
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
                .accessibleButton("Plink Plus Premium")
            }
            RecommendationsList()
        }
    }
    
    // MARK: - Collapse Timer (Pack 6.1)
    
    private func startCollapseTimer() {
        collapseTask?.cancel()
        collapseTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000) // 6 секунд
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        buttonsExpanded = false
                    }
                }
            }
        }
    }
    
    private func resetCollapseTimer() {
        // Развернуть мгновенно
        if !buttonsExpanded {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                buttonsExpanded = true
            }
        }
        // Перезапустить таймер
        startCollapseTimer()
    }
}

// MARK: - Action Button (expand/collapse component)

private struct ActionButton: View {
    let icon: String
    let title: String
    let isExpanded: Bool
    let gradient: LinearGradient
    
    var body: some View {
        ZStack {
            if isExpanded {
                // Развернутое состояние: иконка + надпись
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                    Text(title)
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(gradient, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                // Свёрнутое состояние: только иконка
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(gradient, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                    .transition(.scale(scale: 1.1).combined(with: .opacity))
            }
        }
    }
}

// MARK: - TabRouter

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

// MARK: - Stubs

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

#Preview {
    HomeViewFixed()
        .environmentObject(TabRouter.shared)
}
