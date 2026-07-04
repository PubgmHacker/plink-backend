import SwiftUI

// MARK: - SettingsView (Pack 7: фикс двойных нажатий)
// Баг: нужно 2-3 нажатия чтобы открыть пункт настроек
// Причина: конфликт @State bindings с NavigationLink внутри List
// Фикс: использовать NavigationLink с destination напрямую (без .sheet + state)

struct SettingsViewFixed: View {
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            List {
                // Premium section
                Section {
                    Button {
                        showPaywall = true
                        HapticManager.shared.tap()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(Color.plinkPremiumGradient)
                                .frame(width: 28)
                            VStack(alignment: .leading) {
                                Text("Plink Premium")
                                    .foregroundStyle(.primary)
                                Text("Откройте все возможности")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                }
                
                // Pack 7: Account — каждый пункт прямым NavigationLink
                Section("Аккаунт") {
                    NavigationLink {
                        ProfileViewFixed()
                    } label: {
                        settingsRowLabel(
                            icon: "person.fill",
                            iconColor: .plinkProfile,
                            title: "Профиль"
                        )
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                    
                    NavigationLink {
                        ReferralView()
                    } label: {
                        settingsRowLabel(
                            icon: "gift.fill",
                            iconColor: .plinkPremium,
                            title: "Пригласить друзей"
                        )
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                    
                    NavigationLink {
                        TwoFactorSetupView()
                    } label: {
                        settingsRowLabel(
                            icon: "shield.checkered",
                            iconColor: .plinkLive,
                            title: "Двухфакторная аутентификация"
                        )
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                }
                
                // Preferences — все через NavigationLink
                Section("Настройки") {
                    NavigationLink {
                        NotificationsView()
                    } label: {
                        settingsRowLabel(
                            icon: "bell.fill",
                            iconColor: .plinkNotifications,
                            title: "Уведомления"
                        )
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                    
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        settingsRowLabel(
                            icon: "lock.fill",
                            iconColor: .plinkFriends,
                            title: "Конфиденциальность"
                        )
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                    
                    NavigationLink {
                        LanguagePickerView()
                    } label: {
                        settingsRowLabel(
                            icon: "globe",
                            iconColor: .plinkAI,
                            title: "Язык"
                        )
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                }
                
                // Subscription info
                Section("Подписка") {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundStyle(.plinkPrimary)
                            .frame(width: 28)
                        VStack(alignment: .leading) {
                            Text("Текущий план")
                            Text("Бесплатная версия")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Купить Premium") {
                            showPaywall = true
                        }
                        .font(.caption.bold())
                        .buttonStyle(.borderedProminent)
                        .tint(.plinkPremium)
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.plinkBgPrimary)
            .navigationTitle("Настройки")
            // Pack 7: только ОДИН .sheet для paywall — без конфликтов
            .sheet(isPresented: $showPaywall) { 
                PaywallView() 
            }
        }
    }
    
    // Pack 7: вынесенная row label (без Button внутри Button)
    @ViewBuilder
    private func settingsRowLabel(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 28, alignment: .center)
            
            Text(title)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsViewFixed()
}
