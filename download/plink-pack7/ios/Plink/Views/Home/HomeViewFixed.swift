import SwiftUI

// MARK: - HomeView (Pack 7: разные цвета для разных элементов)
// Pack 6: всё было фиолетового цвета (gradient)
// Pack 7: каждая фича — свой цвет:
//   - "Создать комнату" → Rooms (Purple)
//   - "Присоединиться" → Friends (Pink)  
//   - "Смотрят сейчас" → Live (Green)
//   - "Рекомендации" → AI (Cyan)
//   - "Plink+" → Premium (Gold)

struct HomeViewFixed: View {
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var showPaywall = false
    @State private var showCreateRoom = false
    
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
        .onTapGesture { resetCollapseTimer() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showCreateRoom) { CreateRoomView() }
        .task { startCollapseTimer() }
        .onDisappear { collapseTask?.cancel() }
    }
    
    private var heroSection: some View {
        VStack(spacing: 12) {
            Text("Plink")
                .font(.largeTitle.bold())
                // Pack 7: brand gradient вместо одного цвета
                .foregroundStyle(Color.plinkGradient)
            
            Text("Смотрите вместе с друзьями")
                .font(.subheadline)
                .foregroundStyle(.plinkTextSecondary)
        }
        .padding(.top, 20)
    }
    
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
                    gradient: Color.plinkRoomsGradient  // Pack 7: Purple
                )
            }
            .accessibleButton("Создать комнату")
            
            Button {
                tabRouter.switchToJoinRoom()
                HapticManager.shared.tap()
                resetCollapseTimer()
            } label: {
                ActionButton(
                    icon: "arrow.right.circle.fill",
                    title: "Присоединиться",
                    isExpanded: buttonsExpanded,
                    gradient: Color.plinkFriendsGradient  // Pack 7: Pink
                )
            }
            .accessibleButton("Присоединиться")
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: buttonsExpanded)
    }
    
    // Pack 7: "Смотрят сейчас" — Live (Green)
    private var watchingNowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tv.fill")
                    .foregroundStyle(.plinkLive)  // ← Green
                Text("Смотрят сейчас").font(.headline)
                Spacer()
            }
            ActiveRoomsList()
        }
    }
    
    // Pack 7: "Рекомендации" — AI (Cyan), "Plink+" — Premium (Gold)
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.plinkAI)  // ← Cyan
                Text("Рекомендации").font(.headline)
                Spacer()
                Button {
                    showPaywall = true
                } label: {
                    Text("Plink+")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.plinkPremiumGradient, in: Capsule())  // ← Gold
                        .foregroundStyle(.white)
                }
                .accessibleButton("Plink Premium")
            }
            RecommendationsList()
        }
    }
    
    private func startCollapseTimer() {
        collapseTask?.cancel()
        collapseTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
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
        if !buttonsExpanded {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                buttonsExpanded = true
            }
        }
        startCollapseTimer()
    }
}

private struct ActionButton: View {
    let icon: String
    let title: String
    let isExpanded: Bool
    let gradient: LinearGradient
    
    var body: some View {
        ZStack {
            if isExpanded {
                VStack(spacing: 8) {
                    Image(systemName: icon).font(.system(size: 32))
                    Text(title).font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(gradient, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
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

// MARK: - Stubs (с разными цветами)

private struct ActiveRoomsList: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                HStack {
                    // Pack 7: аватарка комнаты — Rooms gradient
                    Circle().fill(Color.plinkRoomsGradient).frame(width: 40, height: 40)
                    VStack(alignment: .leading) {
                        Text("Lofi beats 🎵").font(.subheadline.bold())
                        Text("5 участников • YouTube").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Pack 7: код — Live (Green) badge
                    Text("AB12CD")
                        .font(.caption.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.plinkLive.opacity(0.2), in: Capsule())
                        .foregroundStyle(.plinkLive)
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
                ForEach(0..<5, id: \.self) { _ in
                    VStack(alignment: .leading) {
                        // Pack 7: разные цвета для разных карточек
                        RoundedRectangle(cornerRadius: 12)
                            .fill([
                                Color.plinkRoomsGradient,
                                Color.plinkFriendsGradient,
                                Color.plinkAIGradient,
                                Color.plinkProfileGradient,
                                Color.plinkPremiumGradient,
                            ][Int.random(in: 0..<5)])
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
