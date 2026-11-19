import SwiftUI

struct UFitNotificationOpeningContent: View {
    let phase: UFitNotificationOpeningPhase
    let onClose: () -> Void
    let onRetry: () -> Void
    let onSignIn: () -> Void
    private enum Copy {
        static let title = String(localized: "Notification")
        static let opening = String(localized: "Ouverture de votre notification")
        static let signIn = String(localized: "Connectez-vous pour continuer")
        static let account = String(localized: "Utilisez le compte destinataire de ce message.")
        static let connect = String(localized: "Se connecter")
        static let unavailable = String(localized: "Notification indisponible")
        static let access = String(localized: "Ce message ou son contenu n’est pas accessible avec ce compte.")
        static let close = String(localized: "Fermer")
        static let failed = String(localized: "Ouverture interrompue")
        static let retry = String(localized: "Réessayer")
        static let lock = "lock", bell = "bell.slash", network = "wifi.exclamationmark"
    }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onClose)
            ScrollView {
                VStack(spacing: UFitSpace.xl) {
                    switch phase {
                    case .waiting, .loading, .ready: UFitLoading(Copy.opening)
                    case .signIn: UFitEmptyState(title: Copy.signIn, message: Copy.account, symbol: Copy.lock, actionTitle: Copy.connect, action: onSignIn)
                    case .unavailable: UFitEmptyState(title: Copy.unavailable, message: Copy.access, symbol: Copy.bell, actionTitle: Copy.close, action: onClose)
                    case .failed(let message): UFitEmptyState(title: Copy.failed, message: message, symbol: Copy.network, actionTitle: Copy.retry, action: onRetry)
                    }
                }.frame(maxWidth: .infinity).padding(UFitSpace.xl)
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}
