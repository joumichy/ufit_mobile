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
    @State private var photoStore: UFitProfileImageStore?

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
                    onNotifications: onNotifications, onDeleteAccount: onDeleteAccount, onBack: onBack,
                    photoHeader: photoHeader(user))
            } else if let message = session.message {
                UFitEmptyState(title: String(localized: "Compte indisponible"), message: message,
                    symbol: "person.crop.circle.badge.exclamationmark", actionTitle: String(localized: "Réessayer"),
                    action: { Task { await session.reloadProfile() } })
            } else { UFitLoading() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ufitCanvas)
        .task { if session.isSignedIn && session.user == nil { await session.reloadProfile() } }
        .task(id: session.user?.id) {
            guard let user = session.user, let id = UUID(uuidString: user.id) else { photoStore = nil; return }
            if photoStore?.accountID != user.id { photoStore = UFitProfileImageStore(scope: .init(kind: .account, ownerID: id), session: session) }
        }
    }
    private func photoHeader(_ user: UFitCurrentUser) -> AnyView {
        if let photoStore, photoStore.accountID == user.id {
            return AnyView(UFitProfileImageHost(store: photoStore,
                name: user.displayName.flatMap { $0.isEmpty ? nil : $0 }, detail: user.email))
        }
        if UUID(uuidString: user.id) == nil { return AnyView(UFitFieldError(message: UFitPhotoError.invalidResponse.localizedDescription)) }
        return AnyView(UFitLoading(UFitProfileImageCopy.loading))
    }

}
