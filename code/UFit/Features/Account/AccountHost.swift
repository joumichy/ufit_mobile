import SwiftUI

struct UFitAccountHost: View {
    let session: UFitSessionStore
    let onSignedOut: () -> Void
    var onOrders: (() -> Void)?
    var onApplications: (() -> Void)?
    var onChooseExperience: (() -> Void)?
    var onNotifications: (() -> Void)?
    var onDeleteAccount: (() -> Void)?
    var onBack: (() -> Void)?

    var body: some View {
        Group {
            if let user = session.user {
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
        .task { if session.user == nil { await session.reloadProfile() } }
    }
}
