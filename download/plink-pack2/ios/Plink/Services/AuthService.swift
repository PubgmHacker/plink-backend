import Foundation

// MARK: - Auth Service (Pack 2: Auto-refresh + Keychain)
/// Полностью переработанный AuthService с:
/// - Хранением access + refresh tokens в Keychain (не в UserDefaults!)
/// - Автоматическим refresh при истечении access token
/// - Авто-логином при запуске приложения
/// - Mutex на одновременные refresh запросы

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var isRefreshing = false
    
    private let api = APIClient.shared
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    // Keychain keys
    private enum KeychainKeys {
        static let accessToken = "plink.accessToken"
        static let refreshToken = "plink.refreshToken"
        static let accessExpiresAt = "plink.accessExpiresAt"
        static let savedUser = "plink.savedUser"
    }
    
    // URL для auth endpoints
    private let baseURL = URL(string: "https://plink-backend-production-ef31.up.railway.app/api")!
    
    // Mutex чтобы не запускать несколько refresh одновременно
    private var refreshTask: Task<String?, Error>?
    
    private init() {
        loadTokensFromKeychain()
    }
    
    // MARK: - Load from Keychain при запуске
    
    private func loadTokensFromKeychain() {
        guard let access = KeychainHelper.read(for: KeychainKeys.accessToken),
              let refresh = KeychainHelper.read(for: KeychainKeys.refreshToken),
              let expiresStr = KeychainHelper.read(for: KeychainKeys.accessExpiresAt),
              let expiresAt = TimeInterval(expiresStr) else {
            // Нет сохранённых токенов — пользователь не залогинен
            return
        }
        
        api.authToken = access
        
        // Если access истёк — попробуем refresh
        if Date().timeIntervalSince1970 >= expiresAt - 60 { // -60s buffer
            Task {
                _ = try? await refreshAccessToken()
            }
        }
        
        // Загружаем сохранённого пользователя
        if let userData = KeychainHelper.read(for: KeychainKeys.savedUser)?.data(using: .utf8),
           let user = try? decoder.decode(User.self, from: userData) {
            currentUser = user
            isAuthenticated = true
        }
    }
    
    // MARK: - Sign Up
    
    func signup(email: String, password: String, username: String) async throws -> User {
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "username": username
        ]
        
        let (data, response) = try await sendRequest(
            to: baseURL.appendingPathComponent("auth/signup"),
            method: "POST",
            body: body
        )
        
        return try await handleAuthResponse(data: data, response: response)
    }
    
    // MARK: - Sign In
    
    func signin(email: String, password: String) async throws -> User {
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        let (data, response) = try await sendRequest(
            to: baseURL.appendingPathComponent("auth/signin"),
            method: "POST",
            body: body
        )
        
        return try await handleAuthResponse(data: data, response: response)
    }
    
    // MARK: - Refresh Token (автоматически)
    
    /// Возвращает свежий access token. Если текущий ещё валиден — возвращает его.
    /// Если истёк — делает /auth/refresh и возвращает новый.
    func getValidAccessToken() async throws -> String {
        // 1. Проверяем есть ли вообще токен
        guard let access = KeychainHelper.read(for: KeychainKeys.accessToken) else {
            throw AuthError.notAuthenticated
        }
        
        // 2. Проверяем expires
        guard let expiresStr = KeychainHelper.read(for: KeychainKeys.accessExpiresAt),
              let expiresAt = TimeInterval(expiresStr) else {
            throw AuthError.notAuthenticated
        }
        
        // 3. Если валиден — возвращаем (с буфером 60 сек)
        if Date().timeIntervalSince1970 < expiresAt - 60 {
            return access
        }
        
        // 4. Если истёк — рефрешим
        return try await refreshAccessToken()
    }
    
    /// Принудительно обновить access token через refresh token
    func refreshAccessToken() async throws -> String {
        // Mutex — если уже идёт refresh, ждём его
        if let existing = refreshTask {
            return try await existing.value ?? ""
        }
        
        let task = Task<String?, Error> { [weak self] in
            guard let self else { throw AuthError.notAuthenticated }
            
            guard let refresh = KeychainHelper.read(for: KeychainKeys.refreshToken) else {
                await MainActor.run { self.clearSession() }
                throw AuthError.notAuthenticated
            }
            
            self.isRefreshing = true
            defer { Task { @MainActor in self.isRefreshing = false } }
            
            let body = ["refreshToken": refresh]
            
            do {
                let (data, response) = try await self.sendRequest(
                    to: self.baseURL.appendingPathComponent("auth/refresh"),
                    method: "POST",
                    body: body
                )
                
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    await MainActor.run { self.clearSession() }
                    throw AuthError.refreshFailed
                }
                
                let payload = try self.decoder.decode(RefreshResponse.self, from: data)
                
                // Сохраняем новые токены в Keychain
                await MainActor.run {
                    KeychainHelper.save(payload.token, for: self.KeychainKeys.accessToken)
                    KeychainHelper.save(payload.refreshToken, for: self.KeychainKeys.refreshToken)
                    KeychainHelper.save(String(payload.accessExpiresAt), for: self.KeychainKeys.accessExpiresAt)
                    self.api.authToken = payload.token
                }
                
                return payload.token
            } catch {
                await MainActor.run { self.clearSession() }
                throw error
            }
        }
        
        refreshTask = task
        defer { refreshTask = nil }
        
        guard let token = try await task.value else {
            throw AuthError.refreshFailed
        }
        return token
    }
    
    // MARK: - Logout
    
    func logout() async {
        // Сообщаем бэкенду отозвать refresh tokens
        if let _ = KeychainHelper.read(for: KeychainKeys.accessToken) {
            _ = try? await sendRequest(
                to: baseURL.appendingPathComponent("auth/logout"),
                method: "POST",
                body: [:],
                authenticated: true
            )
        }
        clearSession()
    }
    
    private func clearSession() {
        KeychainHelper.delete(for: KeychainKeys.accessToken)
        KeychainHelper.delete(for: KeychainKeys.refreshToken)
        KeychainHelper.delete(for: KeychainKeys.accessExpiresAt)
        KeychainHelper.delete(for: KeychainKeys.savedUser)
        
        api.authToken = nil
        currentUser = nil
        isAuthenticated = false
    }
    
    // MARK: - Response Handler
    
    private func handleAuthResponse(data: Data, response: URLResponse) async throws -> User {
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        switch http.statusCode {
        case 200...299:
            let payload = try decoder.decode(AuthResponse.self, from: data)
            
            // Сохраняем токены в Keychain
            KeychainHelper.save(payload.token, for: KeychainKeys.accessToken)
            KeychainHelper.save(payload.refreshToken, for: KeychainKeys.refreshToken)
            KeychainHelper.save(String(payload.accessExpiresAt), for: KeychainKeys.accessExpiresAt)
            
            // Сохраняем пользователя (тоже в Keychain, как JSON)
            if let userData = try? encoder.encode(payload.user),
               let userString = String(data: userData, encoding: .utf8) {
                KeychainHelper.save(userString, for: KeychainKeys.savedUser)
            }
            
            api.authToken = payload.token
            currentUser = payload.user
            isAuthenticated = true
            
            return payload.user
            
        case 401:
            throw AuthError.invalidCredentials
        case 409:
            throw AuthError.alreadyExists
        case 429:
            throw AuthError.rateLimited
        default:
            let errBody = try? decoder.decode(ErrorBody.self, from: data)
            throw AuthError.serverError(http.statusCode, errBody?.error ?? "Unknown")
        }
    }
    
    // MARK: - Network helper
    
    private func sendRequest(
        to url: URL,
        method: String,
        body: [String: Any],
        authenticated: Bool = false
    ) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        if !body.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        if authenticated {
            let token = try await getValidAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return try await session.data(for: request)
    }
}

// MARK: - Response Models

private struct AuthResponse: Codable {
    let token: String
    let refreshToken: String
    let accessExpiresAt: TimeInterval
    let user: User
}

private struct RefreshResponse: Codable {
    let token: String
    let refreshToken: String
    let accessExpiresAt: TimeInterval
    let user: User?
}

private struct ErrorBody: Codable {
    let error: String?
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case alreadyExists
    case rateLimited
    case refreshFailed
    case invalidResponse
    case serverError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Не авторизован. Войдите заново."
        case .invalidCredentials: return "Неверный email или пароль"
        case .alreadyExists: return "Пользователь с таким email/username уже существует"
        case .rateLimited: return "Слишком много попыток. Попробуйте позже."
        case .refreshFailed: return "Сессия истекла. Войдите заново."
        case .invalidResponse: return "Неверный ответ сервера"
        case .serverError(let code, let msg): return "Ошибка сервера (\(code)): \(msg)"
        }
    }
}
