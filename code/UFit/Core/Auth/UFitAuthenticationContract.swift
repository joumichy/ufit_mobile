import Foundation
import Supabase

enum UFitAuthenticationHTTP {
    static let unauthorized = 401
    static let get = "GET"
    static let me = "me"
}

#if DEBUG
enum UFitDevelopmentLogin {
    static let alias = "test"
    static let path = "auth/development-login/test"
    struct Resolution: Decodable {
        let alias: String
        let email: String
        let supabaseURL: URL
    }
}
#endif

enum UFitAuthenticationCallback {
    enum Purpose { case confirmation, recovery }
    static let scheme = "ufit", host = "auth", confirmationPath = "/callback", recoveryPath = "/recovery"
    private static let authoritySeparator = "://"
    static let confirmationURL = URL(string: scheme + authoritySeparator + host + confirmationPath)!
    static let recoveryURL = URL(string: scheme + authoritySeparator + host + recoveryPath)!
    static let nameMetadata = "full_name"
    static let nonceLength = 32, hexadecimalByte = "%02x"
    static func purpose(_ url: URL) -> Purpose? {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == host,
              url.user == nil, url.password == nil, url.port == nil else { return nil }
        switch url.path {
        case confirmationPath: return .confirmation
        case recoveryPath: return .recovery
        default: return nil
        }
    }
}

enum UFitAuthenticationFailure: LocalizedError {
    case credentials, unconfirmed, rateLimited, expiredLink, weakPassword, samePassword, appleUnavailable, unavailable, offline, sessionExpired
    init?(_ error: Error) {
        if error is URLError { self = .offline; return }
        guard let error = error as? AuthError else { return nil }
        switch error.errorCode {
        case .invalidCredentials: self = .credentials
        case .emailNotConfirmed: self = .unconfirmed
        case .overRequestRateLimit, .overEmailSendRateLimit: self = .rateLimited
        case .otpExpired, .flowStateExpired, .flowStateNotFound: self = .expiredLink
        case .weakPassword: self = .weakPassword
        case .samePassword: self = .samePassword
        case .oauthProviderNotSupported, .providerDisabled: self = .appleUnavailable
        case .sessionNotFound, .sessionExpired, .refreshTokenNotFound, .refreshTokenAlreadyUsed: self = .sessionExpired
        default:
            switch error {
            case .pkceGrantCodeExchange, .implicitGrantRedirect: self = .expiredLink
            default: self = .unavailable
            }
        }
    }
    var errorDescription: String? {
        switch self {
        case .credentials: String(localized: "L’adresse e-mail ou le mot de passe est incorrect.")
        case .unconfirmed: String(localized: "Confirmez votre adresse e-mail avant de vous connecter.")
        case .rateLimited: String(localized: "Trop de tentatives rapprochées. Patientez un moment avant de réessayer.")
        case .expiredLink: String(localized: "Ce lien ne peut plus être utilisé. Demandez un nouveau lien depuis cet iPhone.")
        case .weakPassword: String(localized: "Ce mot de passe n’est pas assez sûr. Choisissez-en un autre.")
        case .samePassword: String(localized: "Choisissez un mot de passe différent du précédent.")
        case .appleUnavailable: String(localized: "La connexion Apple est momentanément indisponible. Utilisez votre adresse e-mail.")
        case .unavailable: String(localized: "La demande n’a pas pu aboutir. Réessayez dans un moment.")
        case .offline: String(localized: "La connexion au service a été interrompue. Vérifiez votre réseau et réessayez.")
        case .sessionExpired: String(localized: "Reconnectez-vous pour continuer.")
        }
    }
}
