import Foundation
import Security

// MARK: - KeychainHelper (Pack 6: добавлена миграция старых токенов)
/// Канонический KeychainHelper с правильным kSecAttrService + accessible.
/// Pack 6: добавлена one-time migration для токенов без service.

enum KeychainHelper {
    private static let service = "app.plink.auth"
    
    /// Ключи, для которых нужна миграция (Yandex, Plink auth и т.д.)
    private static let migrationKeys = [
        "yandex_jwt",
        "yandex_user",
        "plink.authToken",
        "plink.refreshToken",
        "plink.accessExpiresAt",
        "plink.savedUser",
    ]
    
    /// Выполнить миграцию один раз при запуске приложения.
    /// Переносит токены из legacy хранилища (без service) в новое.
    static func migrateLegacyTokensIfNeeded() {
        let defaults = UserDefaults.standard
        let migrationKey = "plink.keychainMigration.v1.completed"
        
        guard !defaults.bool(forKey: migrationKey) else { return }
        
        print("[Keychain] Starting legacy token migration...")
        
        for key in migrationKeys {
            // 1. Проверить есть ли уже значение в новом хранилище
            if read(for: key) != nil {
                continue
            }
            
            // 2. Найти в legacy хранилище (без service)
            let legacyQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(legacyQuery as CFDictionary, &result)
            
            if status == errSecSuccess, let data = result as? Data,
               let value = String(data: data, encoding: .utf8) {
                // 3. Сохранить в новом формате
                save(value, for: key)
                // 4. Удалить из legacy
                SecItemDelete(legacyQuery as CFDictionary)
                print("[Keychain] Migrated: \(key)")
            }
        }
        
        defaults.set(true, forKey: migrationKey)
        print("[Keychain] Migration completed")
    }
    
    static func save(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }
    
    static func read(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
