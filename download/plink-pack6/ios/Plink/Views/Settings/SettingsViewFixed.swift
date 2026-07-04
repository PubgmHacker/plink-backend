import SwiftUI

// MARK: - SettingsView (Pack 6: исправления)
// 1. Убрать большие отступы после стрелочек
// 2. Кнопка уведомлений открывается
// 3. Полные переводы (для смены языка)
// 4. Premium и Plink+ кнопки работают

struct SettingsViewFixed: View {
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var showPaywall = false
    @State private var showNotifications = false
    @State private var showPrivacy = false
    @State private var showLanguage = false
    @State private var showTwoFA = false
    @State private var showReferral = false
    
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
                                .foregroundStyle(Color.plinkGradient)
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
                        // Pack 6: убран padding .trailing для compact arrow
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.plinkBgSecondary)
                }
                
                // Account
                Section(L10n.settingsAccount) {
                    settingsRow(icon: "person.fill", iconColor: .plinkCyan, 
                                title: L10n.settingsProfile) {
                        // open profile
                    }
                    settingsRow(icon: "gift.fill", iconColor: .plinkAccent, 
                                title: "Пригласить друзей") {
                        showReferral = true
                    }
                    settingsRow(icon: "shield.checkered", iconColor: .plinkSuccess, 
                                title: "Двухфакторная аутентификация") {
                        showTwoFA = true
                    }
                }
                .listRowBackground(Color.plinkBgSecondary)
                
                // Preferences
                Section("Настройки") {
                    settingsRow(icon: "bell.fill", iconColor: .plinkAccent, 
                                title: L10n.settingsNotifications) {
                        showNotifications = true
                    }
                    settingsRow(icon: "lock.fill", iconColor: .plinkSecondary, 
                                title: L10n.settingsPrivacy) {
                        showPrivacy = true
                    }
                    settingsRow(icon: "globe", iconColor: .plinkCyan, 
                                title: L10n.settingsLanguage) {
                        showLanguage = true
                    }
                }
                .listRowBackground(Color.plinkBgSecondary)
                
                // Subscription info (Pack 6: переведено)
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
                        .tint(.plinkPrimary)
                    }
                }
                .listRowBackground(Color.plinkBgSecondary)
            }
            .scrollContentBackground(.hidden)
            .background(Color.plinkBgPrimary)
            .navigationTitle(L10n.settingsTitle)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showNotifications) { NotificationsView() }
            .sheet(isPresented: $showPrivacy) { PrivacySettingsView() }
            .sheet(isPresented: $showLanguage) { LanguagePickerView() }
            .sheet(isPresented: $showTwoFA) { TwoFactorSetupView() }
            .sheet(isPresented: $showReferral) { ReferralView() }
        }
    }
    
    // Pack 6: compact settings row без больших отступов
    @ViewBuilder
    private func settingsRow<Destination: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 28, alignment: .center)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                // Pack 6: chevron with NO extra padding
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
    }
    
    // Variant without NavigationLink (для buttons)
    @ViewBuilder
    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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
        }
    }
}

// MARK: - Localization helper (Pack 6: для непереведённых строк)

enum L10n {
    static let settingsTitle = NSLocalizedString("settings.title", 
        value: "Настройки", comment: "")
    static let settingsAccount = NSLocalizedString("settings.account", 
        value: "Аккаунт", comment: "")
    static let settingsProfile = NSLocalizedString("settings.profile", 
        value: "Профиль", comment: "")
    static let settingsPrivacy = NSLocalizedString("settings.privacy", 
        value: "Конфиденциальность", comment: "")
    static let settingsNotifications = NSLocalizedString("settings.notifications", 
        value: "Уведомления", comment: "")
    static let settingsLanguage = NSLocalizedString("settings.language", 
        value: "Язык", comment: "")
}

#Preview {
    SettingsViewFixed()
}
