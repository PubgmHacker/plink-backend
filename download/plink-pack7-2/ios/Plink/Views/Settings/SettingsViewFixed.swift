import SwiftUI

// MARK: - SettingsView (Pack 7.2: без двойных нажатий + разные цвета)
// Каждая строка настроек — свой цвет иконки (не все одного цвета)

struct SettingsViewFixed: View {
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            List {
                // Pack 7.2: Premium section — строгий Onyx + Gold
                Section {
                    Button {
                        showPaywall = true
                        HapticManager.shared.tap()
                    } label: {
                        HStack(spacing: 12) {
                            // Pack 7.2: иконка на Onyx с Gold border (строго)
                            ZStack {
                                Circle().fill(Color.plinkOnyx)
                                Circle().stroke(Color.plinkPremiumGold, lineWidth: 1.5)
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(Color.plinkPremiumGold)
                                    .font(.body)
                            }
                            .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading) {
                                Text("Plink Premium")
                                    .foregroundStyle(.primary)
                                    .font(.body.weight(.medium))
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
                
                // Pack 7.2: Account — каждая иконка своего цвета
                Section("Аккаунт") {
                    NavigationLink {
                        ProfileViewFixed()
                    } label: {
                        settingsRowLabel(icon: "person.fill", iconColor: .plinkProfile, title: "Профиль")
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                    
                    NavigationLink {
                        ReferralView()
                    } label: {
                        settingsRowLabel(icon: "gift.fill", iconColor: .plinkPremiumGold, title: "Пригласить друзей")
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                    
                    NavigationLink {
                        TwoFactorSetupView()
                    } label: {
                        settingsRowLabel(icon: "shield.checkered", iconColor: .plinkLive, title: "Двухфакторная аутентификация")
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                }
                
                // Pack 7.2: Preferences — каждая иконка своего цвета
                Section("Настройки") {
                    NavigationLink {
                        NotificationsView()
                    } label: {
                        settingsRowLabel(icon: "bell.fill", iconColor: .plinkNotifications, title: "Уведомления")
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                    
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        settingsRowLabel(icon: "lock.fill", iconColor: .plinkFriends, title: "Конфиденциальность")
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                    
                    NavigationLink {
                        LanguagePickerView()
                    } label: {
                        settingsRowLabel(icon: "globe", iconColor: .plinkAI, title: "Язык")
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
                        // Pack 7.2: Premium button — Onyx + Gold (строгий)
                        Button("Купить Premium") {
                            showPaywall = true
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Color.plinkPremiumGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.plinkOnyx, in: Capsule())
                        .overlay(Capsule().stroke(Color.plinkPremiumGold, lineWidth: 1))
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.plinkBgPrimary)
            .navigationTitle("Настройки")
            .sheet(isPresented: $showPaywall) { 
                PaywallView() 
            }
        }
    }
    
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
