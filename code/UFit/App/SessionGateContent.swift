import SwiftUI

struct UFitSessionGateContent: View {
    let session: UFitSessionStore
    private enum Copy {
        static let loading = String(localized: "Connexion à votre compte")
        static let unavailable = String(localized: "Connexion à finaliser")
        static let profileFailed = String(localized: "Votre compte n’a pas pu être chargé. Réessayez.")
        static let changeAccount = String(localized: "Changer de compte")
        static let icon = "person.crop.circle.badge.exclamationmark"
    }

    var body: some View {
        Group {
            if session.isRestoring || session.isHandlingAuthenticationCallback {
                UFitLoading(Copy.loading).preferredColorScheme(.light)
            } else if session.isSignedIn && !session.isBusy && !session.needsNewPassword {
                // The SDK identity can change just before its auth event removes the old profile.
                if session.isLoadingProfile || session.user != nil { UFitLoading(Copy.loading).preferredColorScheme(.light) }
                else {
                    VStack(spacing: UFitSpace.lg) {
                        UFitEmptyState(title: Copy.unavailable, message: session.message ?? Copy.profileFailed,
                            symbol: Copy.icon, actionTitle: UFitFeedbackCopy.retry,
                            action: { Task { await session.reloadProfile() } })
                        UFitActionButton(title: Copy.changeAccount, kind: .secondary) {
                            Task { await session.signOut() }
                        }.padding(.horizontal, UFitSpace.xl)
                    }.padding(.horizontal, UFitSpace.page).preferredColorScheme(.light)
                }
            } else { UFitAuthenticationHost(session: session) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ufitCanvas)
    }
}
