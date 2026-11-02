import Foundation
import Observation
import Supabase

struct UFitRuntimeConfiguration {
    let apiURL: URL
    let supabaseURL: URL?
    let supabaseKey: String?
    static let callbackURL = URL(string: "ufit://auth/callback")!
    private static let resourceName = "UFitRuntime"
    private static let resourceExtension = "plist"
    private static let apiKey = "UFIT_API_BASE_URL"
    private static let authURLKey = "SUPABASE_URL"
    private static let authPublicKey = "SUPABASE_PUBLIC_KEY"
    private static let localAPI = "http://127.0.0.1:4013"

    static func load() -> Self {
        let environment = ProcessInfo.processInfo.environment
        let settings: [String: String]
        if let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
           let data = try? Data(contentsOf: url),
           let decoded = try? PropertyListDecoder().decode([String: String].self, from: data) {
            settings = decoded
        } else { settings = [:] }
        func value(_ key: String) -> String? { environment[key] ?? (Bundle.main.object(forInfoDictionaryKey: key) as? String).flatMap { $0.isEmpty ? nil : $0 } ?? settings[key] }
        return Self(
            apiURL: URL(string: value(apiKey) ?? localAPI)!,
            supabaseURL: value(authURLKey).flatMap(URL.init(string:)),
            supabaseKey: value(authPublicKey)
        )
    }
}

struct UFitCurrentUser: Decodable, Identifiable {
    let id: String
    let email: String
    let displayName: String?
    let avatarUrl: String?
    let status: String
    let roles: [UFitUserRole]
    var canAdminister: Bool { roles.contains(.admin) || roles.contains(.superAdmin) }
    var isCreator: Bool { roles.contains(.creator) }
    var isBrandMember: Bool { roles.contains(.brandOwner) || roles.contains(.brandManager) }
}

enum UFitSessionError: LocalizedError {
    case unavailable, invalidAppleCredential
    var errorDescription: String? {
        switch self {
        case .unavailable: String(localized: "La connexion est momentanément indisponible.")
        case .invalidAppleCredential: String(localized: "Apple n’a pas transmis une identité valide. Réessayez.")
        }
    }
}

@MainActor @Observable
final class UFitSessionStore {
    private(set) var user: UFitCurrentUser?
    private(set) var isRestoring = true
    private(set) var isBusy = false
    private(set) var isSignedIn = false
    var message: String?
    var needsNewPassword = false
    @ObservationIgnored let api: UFitAPIClient
    @ObservationIgnored private let auth: SupabaseClient?
    @ObservationIgnored private var observation: Task<Void, Never>?
    @ObservationIgnored private var profileRequest = UUID()
    @ObservationIgnored private var observedAuthIdentity: UFitAuthSessionIdentity?
    @ObservationIgnored private var profileIdentity: UFitAuthSessionIdentity?
    @ObservationIgnored lazy var deviceNotifications = UFitNotificationDeviceStore(session: self)
    private var authIdentity: UFitAuthSessionIdentity? { UFitAuthSessionIdentity(auth?.auth.currentSession) }
    var notificationContext: UFitNotificationAccountContext? {
        guard isSignedIn, !isRestoring, let user, profileIdentity == authIdentity,
              let sessionID = authIdentity?.sessionID, UFitInstallationHTTP.identifier(user.id) else { return nil }
        return .init(userID: user.id, authSessionID: sessionID)
    }

    init(configuration: UFitRuntimeConfiguration = .load()) {
        let client: SupabaseClient?
        if let url = configuration.supabaseURL, let key = configuration.supabaseKey, !key.isEmpty {
            client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        } else { client = nil }
        auth = client
        api = UFitAPIClient(configuration: UFitAPIConfiguration(baseURL: configuration.apiURL, bearerToken: nil), tokenProvider: {
            guard let client else { return nil }
            return try await client.auth.session.accessToken
        })
    }

    func start() {
        guard observation == nil else { return }
        guard let auth else { isRestoring = false; return }
        observation = Task { [weak self] in
            for await (event, session) in auth.auth.authStateChanges {
                guard !Task.isCancelled, let self else { return }
                let identity = UFitAuthSessionIdentity(session)
                if identity != self.observedAuthIdentity {
                    self.profileRequest = UUID(); self.user = nil; self.profileIdentity = nil
                    self.observedAuthIdentity = identity
                }
                self.isSignedIn = session != nil
                if session == nil { self.deviceNotifications.prepareForAuthentication(); self.user = nil; self.profileIdentity = nil }
                else if self.user == nil || event == .userUpdated { await self.reloadProfile() }
                self.isRestoring = false
                self.deviceNotifications.contextChanged()
                if event == .passwordRecovery { self.needsNewPassword = true }
            }
        }
    }

    func signIn(email: String, password: String) async {
        await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            self.prepareAuthenticationTransition()
            _ = try await auth.auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            self.isSignedIn = true
            await self.reloadProfile()
        }
    }

    func signUp(email: String, password: String, name: String) async {
        await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            self.prepareAuthenticationTransition()
            let response = try await auth.auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, data: ["full_name": .string(name)], redirectTo: UFitRuntimeConfiguration.callbackURL)
            if response.session == nil { self.message = String(localized: "Consultez votre e-mail pour confirmer votre inscription.") }
            else { self.isSignedIn = true; await self.reloadProfile() }
        }
    }

    func signInWithApple(idToken: String, nonce: String) async {
        await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            self.prepareAuthenticationTransition()
            _ = try await auth.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
            self.isSignedIn = true
            await self.reloadProfile()
        }
    }

    func resetPassword(email: String) async {
        await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            try await auth.auth.resetPasswordForEmail(email.trimmingCharacters(in: .whitespacesAndNewlines), redirectTo: UFitRuntimeConfiguration.callbackURL)
            self.message = String(localized: "Si ce compte existe, un lien de réinitialisation vous a été envoyé.")
        }
    }

    func updatePassword(_ password: String) async {
        await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            _ = try await auth.auth.update(user: .init(password: password))
            self.needsNewPassword = false
            self.message = String(localized: "Mot de passe mis à jour.")
        }
    }

    func handle(_ url: URL) async {
        await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            self.prepareAuthenticationTransition()
            _ = try await auth.auth.session(from: url)
            self.isSignedIn = true
            await self.reloadProfile()
        }
    }

    func signOut() async {
        await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            self.prepareAuthenticationTransition()
            try await auth.auth.signOut()
            self.user = nil
            self.isSignedIn = false
        }
    }

    func updateProfile(name: String) async -> Bool {
        await perform {
            let identity = self.authIdentity
            let updated = try await self.api.updateProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            guard self.authIdentity == identity else { throw CancellationError() }
            self.user = updated
        }
    }

    private func prepareAuthenticationTransition() {
        deviceNotifications.prepareForAuthentication()
        profileRequest = UUID(); profileIdentity = nil; user = nil
    }
    func reloadProfile() async {
        let expected = authIdentity, request = UUID(); profileRequest = request
        do {
            let current = try await api.fetchCurrentUser()
            guard authIdentity == expected, profileRequest == request else { return }
            user = current; profileIdentity = expected; message = nil; deviceNotifications.contextChanged()
        } catch {
            guard authIdentity == expected, profileRequest == request else { return }
            message = error.localizedDescription
        }
    }

    @discardableResult
    private func perform(_ operation: () async throws -> Void) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do { try await operation(); return true }
        catch is CancellationError { return false }
        catch {
            if user == nil, auth?.auth.currentSession != nil { await reloadProfile() }
            message = error.localizedDescription; return false
        }
    }
}
