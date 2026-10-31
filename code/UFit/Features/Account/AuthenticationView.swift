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
        static let browse = String(localized: "Explorer les outfits")
        static let send = String(localized: "Envoyer le lien")
        static let save = String(localized: "Enregistrer le mot de passe")
        static let separator = String(localized: "ou")
        static let arrow = "arrow.right"
    }
    private enum Layout {
        static let page: CGFloat = 28
        static let spacing: CGFloat = 20
        static let fieldHeight: CGFloat = 54
        static let radius: CGFloat = 14
        static let titleSize: CGFloat = 34
        static let logoSize: CGFloat = 24
        static let tracking: CGFloat = 7
        static let border: CGFloat = 1
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
                Text(Copy.brand).font(.system(size: Layout.logoSize, weight: .semibold)).tracking(Layout.tracking)
                Text(mode == .signIn || mode == .signUp ? Copy.introduction : mode.title)
                    .font(.system(size: Layout.titleSize, weight: .regular, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, Layout.spacing)
                if mode == .signIn || mode == .signUp {
                    SignInWithAppleButton(.continue, onRequest: onAppleRequest, onCompletion: onAppleComplete)
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: Layout.fieldHeight)
                        .clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                        .disabled(isBusy)
                    HStack {
                        Rectangle().frame(height: Layout.border)
                        Text(Copy.separator).font(.caption)
                        Rectangle().frame(height: Layout.border)
                    }.foregroundStyle(Color.ufitMuted)
                }
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    if mode == .signUp {
                        fieldLabel(Copy.name)
                        TextField(Copy.name, text: $name).textContentType(.name).fieldStyle()
                    }
                    if mode != .newPassword {
                        fieldLabel(Copy.email)
                        TextField(Copy.email, text: $email)
                            .textContentType(.emailAddress).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().fieldStyle()
                    }
                    if mode != .recovery {
                        fieldLabel(Copy.password)
                        SecureField(mode == .signUp || mode == .newPassword ? Copy.passwordMinimum : Copy.password, text: $password)
                            .textContentType(mode == .signIn ? .password : .newPassword).fieldStyle()
                    }
                }.disabled(isBusy)
                if let message {
                    Text(message).font(.callout).foregroundStyle(Color.ufitInk)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                Button(action: onSubmit) {
                    HStack {
                        Spacer()
                        if isBusy { ProgressView().tint(.white) } else { Text(actionTitle); Image(systemName: Copy.arrow) }
                        Spacer()
                    }
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(isBusy || !canSubmit)
                .opacity(canSubmit ? 1 : 0.5)
                if mode == .signIn {
                    Button(Copy.forgotten) { mode = .recovery; password = String() }
                }
                if mode != .newPassword {
                    Button(mode == .signIn ? Copy.create : Copy.existing) {
                        mode = mode == .signIn ? .signUp : .signIn
                        password = String()
                    }
                    Button(Copy.browse, action: onBrowse).foregroundStyle(Color.ufitMuted)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ufitInk)
            .padding(Layout.page)
        }
        .background(Color.white)
        .scrollDismissesKeyboard(.interactively)
    }
    private func fieldLabel(_ label: String) -> some View {
        Text(label).font(.subheadline.weight(.medium))
    }
}

private extension View {
    func fieldStyle() -> some View {
        self.padding().background(Color.ufitBackground, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ufitBorder, lineWidth: 1))
    }
}
