import SwiftUI

// MARK: - ProfileView (Pack 6: убрана шестерёнка)
// Баг: шестерёнка больше не нужна, profile icon в Home уже открывает профиль
// Фикс: убрать иконку settings из ProfileView

struct ProfileViewFixed: View {
    @State private var showSettings = false
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar + name
                    VStack(spacing: 12) {
                        Circle()
                            .fill(Color.plinkGradient)
                            .frame(width: 96, height: 96)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white)
                            )
                        
                        Text("@username")
                            .font(.title2.bold())
                        
                        Text("email@example.com")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Premium banner (если не premium)
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading) {
                                Text("Plink Premium").font(.subheadline.bold())
                                Text("Откройте все возможности").font(.caption)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.plinkBgSecondary, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    
                    // Stats
                    HStack {
                        statTile(icon: "person.2.fill", value: "12", label: "Друзья")
                        statTile(icon: "tv.fill", value: "47", label: "Часов")
                        statTile(icon: "film.fill", value: "23", label: "Комнат")
                    }
                    .padding(.horizontal)
                    
                    // Pack 6: убрана шестерёнка из toolbar
                    // Кнопка "Настройки" теперь только снизу
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
            // Pack 6: УБРАНА шестерёнка из toolbar
            // Раньше было:
            //   .toolbar { ToolbarItem { Button { showSettings = true } label: { Image(systemName: "gear") } } }
            // Теперь её нет — profile icon в Home уже ведёт на Profile
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
    
    private func statTile(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.plinkPrimary)
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
