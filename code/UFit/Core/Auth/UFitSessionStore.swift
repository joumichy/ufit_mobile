import Foundation
import Observation
import Supabase

struct UFitRuntimeConfiguration {
    let apiURL: URL
    let supabaseURL: URL?
    let supabaseKey: String?
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
    private(set) var isLoadingProfile = false
    private(set) var isSignedIn = false
    var message: String?
    var needsNewPassword = false
    private(set) var isHandlingAuthenticationCallback = false
    private(set) var authenticationFailure: UFitAuthenticationFailure?
    @ObservationIgnored private let configuration: UFitRuntimeConfiguration
    @ObservationIgnored lazy var api = UFitAPIClient(
        configuration: UFitAPIConfiguration(baseURL: configuration.apiURL, bearerToken: nil),
        tokenProvider: { [weak self, auth] in
            guard let auth else { return nil }
            let previousToken = auth.auth.currentSession?.accessToken
            do { return try await auth.auth.session.accessToken }
            catch {
                if UFitAuthenticationFailure(error) == .sessionExpired, let previousToken {
                    await self?.invalidateAuthentication(accessToken: previousToken)
                }
                throw error
            }
        }, onAuthenticationRejected: { [weak self] token in
            await self?.invalidateAuthentication(accessToken: token)
        })
    @ObservationIgnored private let auth: SupabaseClient?
    @ObservationIgnored private var observation: Task<Void, Never>?
    @ObservationIgnored private var profileRequest = UUID()
    @ObservationIgnored private var observedAuthIdentity: UFitAuthSessionIdentity?
    @ObservationIgnored private var profileIdentity: UFitAuthSessionIdentity?
    @ObservationIgnored private var deletedAuthSubject: UUID?
    @ObservationIgnored lazy var deviceNotifications = UFitNotificationDeviceStore(session: self)
    private var authIdentity: UFitAuthSessionIdentity? { UFitAuthSessionIdentity(auth?.auth.currentSession) }
    var accountDeletionSubject: UUID? { authIdentity?.subject }
    var notificationContext: UFitNotificationAccountContext? {
        guard isSignedIn, !isRestoring, let user, profileIdentity == authIdentity,
              let sessionID = authIdentity?.sessionID, UFitInstallationHTTP.identifier(user.id) else { return nil }
        return .init(userID: user.id, authSessionID: sessionID)
    }

    init(configuration: UFitRuntimeConfiguration = .load()) {
        self.configuration = configuration
        let client: SupabaseClient?
        if let url = configuration.supabaseURL, let key = configuration.supabaseKey, !key.isEmpty {
            client = SupabaseClient(supabaseURL: url, supabaseKey: key,
                options: .init(auth: .init(redirectToURL: UFitAuthenticationCallback.confirmationURL, flowType: .pkce)))
        } else { client = nil }
        auth = client
    }

    func start() {
        guard observation == nil else { return }
        guard let auth else { isRestoring = false; return }
        observation = Task { [weak self] in
            for await (event, session) in auth.auth.authStateChanges {
                guard !Task.isCancelled, let self else { return }
                if event == .passwordRecovery { self.needsNewPassword = true }
                let identity = UFitAuthSessionIdentity(session)
                if identity != self.observedAuthIdentity {
                    // A callback may already be loading or have published this session's profile.
                    // Its identity guard rejects the old session without cancelling the new request.
                    if self.profileIdentity != identity { self.user = nil; self.profileIdentity = nil }
                    self.observedAuthIdentity = identity
                }
                self.isSignedIn = session != nil && identity?.subject != self.deletedAuthSubject
                if session == nil {
                    self.profileRequest = UUID(); self.isLoadingProfile = false
                    self.deviceNotifications.prepareForAuthentication(); self.user = nil; self.profileIdentity = nil
                }
                else if !self.isHandlingAuthenticationCallback && (self.user == nil || event == .userUpdated) { await self.reloadProfile() }
                self.isRestoring = false
                self.deviceNotifications.contextChanged()
            }
        }
    }

    func signIn(email: String, password: String) async {
        await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            var loginEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            #if DEBUG
            if loginEmail == UFitDevelopmentLogin.alias {
                let resolution: UFitDevelopmentLogin.Resolution = try await self.api.send(
                    UFitAuthenticationHTTP.get, path: UFitDevelopmentLogin.path, cachePolicy: .reloadIgnoringLocalCacheData)
                guard resolution.alias == UFitDevelopmentLogin.alias, resolution.supabaseURL == self.configuration.supabaseURL,
                      !resolution.email.isEmpty else { throw UFitSessionError.unavailable }
                loginEmail = resolution.email
            }
            #endif
            self.prepareAuthenticationTransition()
            _ = try await auth.auth.signIn(email: loginEmail, password: password)
            self.isSignedIn = true
            await self.reloadProfile()
        }
    }

    @discardableResult
    func signUp(email: String, password: String, name: String) async -> Bool {
        await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            self.prepareAuthenticationTransition()
            let response = try await auth.auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password,
                data: [UFitAuthenticationCallback.nameMetadata: .string(name.trimmingCharacters(in: .whitespacesAndNewlines))], redirectTo: UFitAuthenticationCallback.confirmationURL)
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

    @discardableResult
    func resetPassword(email: String) async -> Bool {
        await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            try await auth.auth.resetPasswordForEmail(email.trimmingCharacters(in: .whitespacesAndNewlines), redirectTo: UFitAuthenticationCallback.recoveryURL)
            self.message = String(localized: "Si ce compte existe, un lien de réinitialisation vous a été envoyé.")
        }
    }

    @discardableResult
    func updatePassword(_ password: String) async -> Bool {
        guard needsNewPassword else { message = UFitAuthenticationFailure.expiredLink.localizedDescription; return false }
        return await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            _ = try await auth.auth.update(user: .init(password: password))
            self.needsNewPassword = false
            self.message = String(localized: "Mot de passe mis à jour.")
        }
    }

    func handle(_ url: URL) async {
        guard let purpose = UFitAuthenticationCallback.purpose(url) else { return }
        await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            let previousRecovery = self.needsNewPassword
            self.isHandlingAuthenticationCallback = true
            // The installed SDK emits only signedIn after PKCE exchange. The
            // exact recovery redirect carries purpose before profile publication.
            self.needsNewPassword = purpose == .recovery
            defer { self.isHandlingAuthenticationCallback = false }
            self.prepareAuthenticationTransition()
            do {
                _ = try await auth.auth.session(from: url)
                self.isSignedIn = true
                await self.reloadProfile()
            } catch { self.needsNewPassword = previousRecovery; throw error }
        }
    }

    func resendConfirmation(email: String) async -> Bool {
        await perform {
            guard let auth = self.auth else { throw UFitSessionError.unavailable }
            try await auth.auth.resend(email: email.trimmingCharacters(in: .whitespacesAndNewlines), type: .signup,
                emailRedirectTo: UFitAuthenticationCallback.confirmationURL)
            self.message = UFitAuthenticationCopy.sentAgain
        }
    }

    func cancelPasswordRecovery() async {
        guard !isBusy, needsNewPassword else { return }
        prepareAuthenticationTransition(); needsNewPassword = false; isSignedIn = false; message = nil
        // Local storage is removed by the SDK before its logout request.
        try? await auth?.auth.signOut(scope: .local)
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

    func closeDeletedAccount(subject: UUID) async {
        guard authIdentity?.subject == subject else { return }
        deletedAuthSubject = subject
        prepareAuthenticationTransition()
        isSignedIn = false; needsNewPassword = false; message = nil
        // The SDK removes its persisted local session before its network logout.
        // Server revocation remains the deletion worker's responsibility.
        try? await auth?.auth.signOut(scope: .local)
    }

    private func prepareAuthenticationTransition() {
        deviceNotifications.prepareForAuthentication()
        profileRequest = UUID(); profileIdentity = nil; user = nil; isLoadingProfile = false
    }
    private func invalidateAuthentication(accessToken: String) async {
        // A delayed rejection from the previous account must not close a newer session.
        guard auth?.auth.currentSession?.accessToken == accessToken else { return }
        prepareAuthenticationTransition()
        isSignedIn = false; needsNewPassword = false
        authenticationFailure = .sessionExpired
        message = UFitAuthenticationFailure.sessionExpired.localizedDescription
        try? await auth?.auth.signOut(scope: .local)
    }
    func reloadProfile() async {
        guard authIdentity?.subject != deletedAuthSubject || deletedAuthSubject == nil else { return }
        let expected = authIdentity, request = UUID(); profileRequest = request
        isLoadingProfile = true
        defer { if profileRequest == request { isLoadingProfile = false } }
        do {
            let current = try await api.fetchCurrentUser()
            guard authIdentity == expected, profileRequest == request else { return }
            user = current; profileIdentity = expected; message = nil; deviceNotifications.contextChanged()
        } catch {
            guard authIdentity == expected, profileRequest == request else { return }
            user = nil; profileIdentity = nil; deviceNotifications.contextChanged()
            message = UFitAuthenticationFailure(error)?.localizedDescription ?? error.localizedDescription
        }
    }

    @discardableResult
    private func perform(_ operation: () async throws -> Void) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        message = nil; authenticationFailure = nil
        defer { isBusy = false }
        do { try await operation(); return true }
        catch is CancellationError { return false }
        catch {
            authenticationFailure = UFitAuthenticationFailure(error)
            if user == nil, auth?.auth.currentSession != nil { await reloadProfile() }
            message = authenticationFailure?.localizedDescription ?? error.localizedDescription; return false
        }
    }
}
