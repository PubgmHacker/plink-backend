// Pack 2: iOS Auto-refresh + Keychain
//
// Что добавлено:
// 1. Полностью переработанный AuthService с Keychain storage
// 2. Auto-login при запуске приложения (читает refresh token из Keychain)
// 3. Auto-refresh: при истечении access token автоматически /auth/refresh
// 4. Mutex на одновременные refresh запросы (не делает 10 refresh одновременно)
// 5. Logout отзывает все refresh tokens на бэкенде
// 6. AuthError с понятными сообщениями для пользователя
//
// Файлы:
// - Plink/Services/AuthService.swift — полностью заменить существующий
//
// Что нужно проверить в существующем коде:
// 1. AuthService.shared — используется ли так (singleton)?
//    Если в коде: `let auth = AuthService()` — заменить на `AuthService.shared`
//
// 2. APIClient.shared — используется ли singleton?
//    Если нет — нужно сделать APIClient.shared = APIClient()
//
// 3. User model — должен соответствовать бэкенду:
//    id, username, email, avatarURL, isOnline, isPremium, role, bannedUntil
//
// 4. Удалить дубликат KeychainHelper если он есть в YandexAuthService.swift
//    (используем каноничный из Utilities/KeychainHelper.swift)
