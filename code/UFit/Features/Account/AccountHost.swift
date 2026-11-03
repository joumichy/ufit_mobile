import SwiftUI

struct UFitAccountHost: View {
    let session: UFitSessionStore
    let onSignedOut: () -> Void
    let onSignIn: () -> Void
    var onOrders: (() -> Void)?
    var onApplications: (() -> Void)?
    var onChooseExperience: (() -> Void)?
    var onNotifications: (() -> Void)?
    var onStyles: (() -> Void)?
    var onDeleteAccount: (() -> Void)?
    var onBack: (() -> Void)?
    @State private var photoStore: UFitProfileImageStore?
    private enum Copy {
        static let unavailable = String(localized: "Compte indisponible")
        static let retry = String(localized: "Réessayer")
        static let signOut = String(localized: "Se déconnecter")
        static let icon = "person.crop.circle.badge.exclamationmark"
        static let sessionExpired = String(localized: "Votre session a expiré. Reconnectez-vous pour retrouver vos commandes et vos espaces.")
        static let loadFailed = String(localized: "Votre compte n’a pas pu être chargé. Réessayez.")
    }

    var body: some View {
        Group {
            if session.isRestoring || session.isLoadingProfile && session.user == nil { UFitLoading() }
            else if !session.isSignedIn {
                VStack(spacing: UFitSpace.lg) {
                UFitEmptyState(title: UFitAuthenticationCopy.accountTitle,
                    message: session.authenticationFailure == .sessionExpired ? Copy.sessionExpired : UFitAuthenticationCopy.accountAccess,
                    symbol: UFitAuthenticationCopy.accountIcon, actionTitle: UFitAuthenticationCopy.signIn, action: onSignIn)
                    if let onStyles { UFitButton(UFitStylePreferencesCopy.title, action: onStyles).ufitButtonStyle(.secondary) }
                }.padding(.horizontal, UFitSpace.page)
            } else if let user = session.user {
                UFitAccountView(name: user.displayName ?? String(), email: user.email,
                    isBusy: session.isBusy, message: session.message,
                    onSaveName: { name in Task { await session.updateProfile(name: name) } },
                    onSignOut: { Task {
                        await session.signOut()
                        if !session.isSignedIn { onSignedOut() }
                    } }, onOrders: onOrders, onApplications: onApplications, onChooseExperience: onChooseExperience,
                    onNotifications: onNotifications, onStyles: onStyles, onDeleteAccount: onDeleteAccount, onBack: onBack,
                    photoHeader: photoHeader(user))
            } else if let message = session.message {
                VStack(spacing: UFitSpace.lg) {
                    UFitEmptyState(title: Copy.unavailable, message: accountFailureMessage(message),
                        symbol: Copy.icon, actionTitle: Copy.retry,
                        action: { Task { await session.reloadProfile() } })
                    UFitButton(Copy.signOut) { Task {
                        await session.signOut()
                        if !session.isSignedIn { onSignedOut() }
                    } }.ufitButtonStyle(.text).disabled(session.isBusy)
                }.padding(.horizontal, UFitSpace.page)
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
    private func accountFailureMessage(_ message: String) -> String {
        session.authenticationFailure == nil ? Copy.loadFailed : message
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
