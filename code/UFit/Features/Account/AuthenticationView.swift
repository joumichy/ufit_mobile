import SwiftUI
import AuthenticationServices

enum UFitAuthenticationMode: CaseIterable {
    case signIn, signUp, recovery, newPassword
    var title: String {
        switch self {
        case .signIn: Copy.signIn
        case .signUp: Copy.signUp
        case .recovery: Copy.recovery
        case .newPassword: Copy.newPassword
        }
    }
    fileprivate enum Copy {
        static let signIn = String(localized: "Se connecter")
        static let signUp = String(localized: "Créer mon compte")
        static let recovery = String(localized: "Réinitialiser le mot de passe")
        static let newPassword = String(localized: "Choisir un nouveau mot de passe")
    }
}

struct UFitAuthenticationView: View {
    @Binding var mode: UFitAuthenticationMode
    @Binding var name: String
    @Binding var email: String
    @Binding var password: String
    let isBusy: Bool
    let message: String?
    let onSubmit: () -> Void
    let onAppleRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onAppleComplete: (Result<ASAuthorization, Error>) -> Void
    let onBrowse: () -> Void

    private enum Copy {
        static let brand = "UFIT"
        static let introduction = String(localized: "Votre style.\nDe nouvelles perspectives.")
        static let name = String(localized: "Nom")
        static let email = String(localized: "Adresse e-mail")
        static let password = String(localized: "Mot de passe")
        static let passwordMinimum = String(localized: "Au moins 8 caractères")
        static let forgotten = String(localized: "Mot de passe oublié ?")
        static let existing = String(localized: "J’ai déjà un compte")
        static let create = String(localized: "Créer un compte")
        static let browse = String(localized: "Découvrir les tenues")
        static let send = String(localized: "Envoyer le lien")
        static let save = String(localized: "Enregistrer le mot de passe")
        static let separator = String(localized: "ou")
        static let arrow = "arrow.right"
    }
    private enum Layout {
        static let page: CGFloat = 28
        static let spacing: CGFloat = UFitSpace.lg
        static let fieldHeight: CGFloat = 54
        static let radius: CGFloat = UFitRadius.action
        static let titleSize: CGFloat = UFitTypography.Size.display
        static let logoSize: CGFloat = UFitTypography.Size.section
        static let tracking: CGFloat = 7
        static let border: CGFloat = UFitSpace.hairline
        static let minimumPassword = 8
    }

    private var canSubmit: Bool {
        if mode == .newPassword { return password.count >= Layout.minimumPassword }
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if mode == .recovery { return true }
        return !password.isEmpty && (mode != .signUp || (!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= Layout.minimumPassword))
    }
    private var actionTitle: String {
        switch mode {
        case .recovery: Copy.send
        case .newPassword: Copy.save
        default: mode.title
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.spacing) {
                Text(Copy.brand).ufitFont(size: Layout.logoSize, weight: .semibold).tracking(Layout.tracking)
                Text(mode == .signIn || mode == .signUp ? Copy.introduction : mode.title)
                    .ufitFont(size: Layout.titleSize, weight: .regular, design: .serif)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, Layout.spacing)
                if mode == .signIn || mode == .signUp {
                    UFitAppleSignIn(onRequest: onAppleRequest, onCompletion: onAppleComplete)
                        .disabled(isBusy)
                    HStack {
                        Rectangle().frame(height: Layout.border)
                        Text(Copy.separator).font(UFitTypography.caption)
                        Rectangle().frame(height: Layout.border)
                    }.foregroundStyle(Color.ufitSecondaryText)
                }
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    if mode == .signUp {
                        fieldLabel(Copy.name)
                        UFitInput(Copy.name, text: $name).textContentType(.name)
                    }
                    if mode != .newPassword {
                        fieldLabel(Copy.email)
                        UFitInput(Copy.email, text: $email)
                            .textContentType(.emailAddress).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    if mode != .recovery {
                        fieldLabel(Copy.password)
                        UFitInput(mode == .signUp || mode == .newPassword ? Copy.passwordMinimum : Copy.password, text: $password, isSecure: true)
                            .textContentType(mode == .signIn ? .password : .newPassword)
                    }
                }.disabled(isBusy)
                if let message {
                    Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitInk)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                UFitActionButton(title: actionTitle, isBusy: isBusy, disabled: !canSubmit, action: onSubmit)
                if mode == .signIn {
                    UFitButton(Copy.forgotten) { mode = .recovery; password = String() }
                }
                if mode != .newPassword {
                    UFitButton(mode == .signIn ? Copy.create : Copy.existing) {
                        mode = mode == .signIn ? .signUp : .signIn
                        password = String()
                    }
                    UFitButton(Copy.browse, action: onBrowse).foregroundStyle(Color.ufitSecondaryText)
                }
            }
            .ufitButtonStyle(.text)
            .foregroundStyle(Color.ufitInk)
            .padding(Layout.page)
        }
        .background(Color.ufitCanvas)
        .scrollDismissesKeyboard(.interactively)
    }
    private func fieldLabel(_ label: String) -> some View {
        Text(label).font(UFitTypography.subheadline.weight(.medium))
    }
}
