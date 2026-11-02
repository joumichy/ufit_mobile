import SwiftUI

struct UFitAccountHost: View {
    let session: UFitSessionStore
    let onSignedOut: () -> Void
    let onSignIn: () -> Void
    var onOrders: (() -> Void)?
    var onApplications: (() -> Void)?
    var onChooseExperience: (() -> Void)?
    var onNotifications: (() -> Void)?
    var onDeleteAccount: (() -> Void)?
    var onBack: (() -> Void)?

    var body: some View {
        Group {
            if session.isRestoring { UFitLoading() }
            else if !session.isSignedIn {
                UFitEmptyState(title: UFitAuthenticationCopy.accountTitle, message: UFitAuthenticationCopy.accountAccess,
                    symbol: UFitAuthenticationCopy.accountIcon, actionTitle: UFitAuthenticationCopy.signIn, action: onSignIn)
            } else if let user = session.user {
                UFitAccountView(name: user.displayName ?? String(), email: user.email,
                    isBusy: session.isBusy, message: session.message,
                    onSaveName: { name in Task { await session.updateProfile(name: name) } },
                    onSignOut: { Task {
                        await session.signOut()
                        if !session.isSignedIn { onSignedOut() }
                    } }, onOrders: onOrders, onApplications: onApplications, onChooseExperience: onChooseExperience,
                    onNotifications: onNotifications, onDeleteAccount: onDeleteAccount, onBack: onBack)
            } else if let message = session.message {
                UFitEmptyState(title: String(localized: "Compte indisponible"), message: message,
                    symbol: "person.crop.circle.badge.exclamationmark", actionTitle: String(localized: "Réessayer"),
                    action: { Task { await session.reloadProfile() } })
            } else { UFitLoading() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ufitCanvas)
        .task { if session.isSignedIn && session.user == nil { await session.reloadProfile() } }
    }
}
