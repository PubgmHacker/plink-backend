import SwiftUI

// MARK: - ProfileView (Pack 7.2: аватар без обводки для обычных юзеров)

struct ProfileViewFixed: View {
    @State private var showPaywall = false
    
    private let isPremium: Bool = false
    private let userRole: UserRole = .user
    private let username: String = "username"
    private let email: String = "email@example.com"
    private let avatarURL: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Pack 7.2: AvatarView управляет обводкой
                    AvatarView(
                        imageURL: avatarURL,
                        username: username,
                        size: 96,
                        isPremium: isPremium,
                        role: userRole
                    )
                    .padding(.top, 20)
                    
                    VStack(spacing: 4) {
                        Text("@\(username)").font(.title2.bold())
                        Text(email).font(.subheadline).foregroundStyle(.secondary)
                    }
                    
                    // Pack 7.2: Premium banner — строгий Onyx + Gold
                    if !isPremium {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                // Gold crown на Onyx circle
                                ZStack {
                                    Circle().fill(Color.plinkOnyx)
                                    Circle().stroke(Color.plinkPremiumGold, lineWidth: 1)
                                    Image(systemName: "crown.fill")
                                        .foregroundStyle(Color.plinkPremiumGold)
                                }
                                .frame(width: 32, height: 32)
                                
                                VStack(alignment: .leading) {
                                    Text("Plink Premium").font(.subheadline.bold())
                                    Text("Откройте все возможности").font(.caption)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                                    .foregroundStyle(Color.plinkPremiumGold)
                            }
                            .padding()
                            // Pack 7.2: тёмный фон с тонкой gold границей
                            .background(Color.plinkOnyx, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.plinkPremiumGold.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Stats — каждая своя
                    HStack {
                        statTile(icon: "person.2.fill", value: "12", label: "Друзья", color: .plinkFriends)
                        statTile(icon: "tv.fill", value: "47", label: "Часов", color: .plinkRooms)
                        statTile(icon: "film.fill", value: "23", label: "Комнат", color: .plinkAI)
                    }
                    .padding(.horizontal)
                    
                    NavigationLink {
                        SettingsViewFixed()
                    } label: {
                        Label("Настройки", systemImage: "gearshape.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.plinkBgSecondary, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .accessibleButton("Настройки")
                }
            }
            .background(Color.plinkBgGradient)
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
    
    private func statTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.plinkBgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ProfileViewFixed()
}
