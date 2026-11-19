import SwiftUI

struct UFitCartAccountGate: View {
    let session: UFitSessionStore
    let onBack: () -> Void
    let onSignIn: () -> Void
    @State private var openedAuthentication = false
    private enum Copy {
        static let title = String(localized: "Mon panier")
        static let loading = String(localized: "Ouverture de votre panier")
        static let unavailable = String(localized: "Votre compte n’a pas pu être chargé. Réessayez pour retrouver votre panier.")
        static let retry = String(localized: "Retrouver mon panier")
        static let signIn = String(localized: "Se connecter")
        static let guest = String(localized: "Connectez-vous pour retrouver votre sélection.")
    }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack)
            VStack(alignment: .leading, spacing: UFitSpace.xl) {
                if session.isRestoring || session.isLoadingProfile {
                    UFitLoading(Copy.loading).frame(maxWidth: .infinity)
                } else if session.isSignedIn {
                    Text(Copy.unavailable).font(UFitTypography.body).foregroundStyle(Color.ufitSecondaryText)
                    UFitActionButton(title: Copy.retry) { Task { await session.reloadProfile() } }
                } else {
                    Text(Copy.guest).font(UFitTypography.body).foregroundStyle(Color.ufitSecondaryText)
                    UFitActionButton(title: Copy.signIn, action: onSignIn)
                }
            }.padding(UFitSpace.page).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }.background(Color.ufitCanvas)
        .task(id: session.isRestoring) {
            guard !session.isRestoring else { return }
            if session.isSignedIn && session.user == nil && !session.isLoadingProfile {
                await session.reloadProfile()
            } else if !session.isSignedIn && !openedAuthentication {
                openedAuthentication = true; onSignIn()
            }
        }
    }
}
