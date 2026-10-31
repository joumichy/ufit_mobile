import SwiftUI

struct UFitAccountHost: View {
    let session: UFitSessionStore
    let onSignedOut: () -> Void

    var body: some View {
        Group {
            if let user = session.user {
                UFitAccountView(name: user.displayName ?? String(), email: user.email,
                    isBusy: session.isBusy, message: session.message,
                    onSaveName: { name in Task { await session.updateProfile(name: name) } },
                    onSignOut: { Task {
                        await session.signOut()
                        if !session.isSignedIn { onSignedOut() }
                    } })
            } else if let message = session.message {
                ContentUnavailableView {
                    Label(String(localized: "Compte indisponible"), systemImage: "person.crop.circle.badge.exclamationmark")
                } description: { Text(message) } actions: {
                    Button(String(localized: "Réessayer")) { Task { await session.reloadProfile() } }
                }
            } else { ProgressView() }
        }
        .task { if session.user == nil { await session.reloadProfile() } }
    }
}
