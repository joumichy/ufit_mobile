import SwiftUI
import AuthenticationServices

struct UFitAuthenticationView: View {
    @Binding var mode: UFitAuthenticationMode
    @Binding var name: String
    @Binding var email: String
    @Binding var password: String
    let isBusy: Bool
    let message: String?
    var messageKind: UFitNoticeKind = .information
    let onSubmit: () -> Void
    let onAppleRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onAppleComplete: (Result<ASAuthorization, Error>) -> Void
    let onCancelRecovery: () -> Void
    let onBackToEntry: () -> Void

    private enum Copy {
        static let name = String(localized: "Nom")
        static let email = String(localized: "Adresse e-mail")
        #if DEBUG
        static let identifier = String(localized: "E-mail ou identifiant")
        #endif
        static let password = String(localized: "Mot de passe")
        static let passwordMinimum = String(localized: "Au moins 8 caractères")
        static let forgotten = String(localized: "Mot de passe oublié ?")
        static let existing = String(localized: "J’ai déjà un compte")
        static let create = String(localized: "Créer un compte")
        static let send = String(localized: "Envoyer le lien")
        static let save = String(localized: "Enregistrer le mot de passe")
        static let separator = String(localized: "ou")
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.page
        static let spacing: CGFloat = UFitSpace.lg
        static let titleSize: CGFloat = UFitTypography.Size.display
        static let border: CGFloat = UFitSpace.hairline
    }

    private var canSubmit: Bool {
        if mode == .newPassword { return password.count >= UFitAuthenticationCopy.minimumPassword }
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if mode == .recovery || mode.awaitsEmail { return true }
        return !password.isEmpty && (mode != .signUp || (!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= UFitAuthenticationCopy.minimumPassword))
    }
    private var actionTitle: String {
        switch mode {
        case .recovery: Copy.send
        case .confirmEmail, .recoverySent: UFitAuthenticationCopy.resend
        case .newPassword: Copy.save
        default: mode.title
        }
    }
    private var identifierLabel: String {
        #if DEBUG
        if mode == .signIn { return Copy.identifier }
        #endif
        return Copy.email
    }

    var body: some View {
        VStack(spacing: .zero) {
        DetailHeader(onBack: back).disabled(isBusy)
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.spacing) {
                UFitWordmark()
                Text(mode.title)
                    .ufitFont(size: Layout.titleSize, weight: .regular, design: .serif)
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                if mode == .signIn || mode == .signUp {
                    UFitAppleSignIn(onRequest: onAppleRequest, onCompletion: onAppleComplete)
                        .disabled(isBusy)
                    HStack {
                        Rectangle().frame(height: Layout.border)
                        Text(Copy.separator).font(UFitTypography.caption)
                        Rectangle().frame(height: Layout.border)
                    }.foregroundStyle(Color.ufitSecondaryText)
                }
                if mode.awaitsEmail {
                    Text(mode == .confirmEmail ? UFitAuthenticationCopy.confirmationDetail : UFitAuthenticationCopy.recoveryDetail)
                        .font(UFitTypography.body)
                    Text(email.trimmingCharacters(in: .whitespacesAndNewlines)).font(UFitTypography.headline)
                } else {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    if mode == .signUp {
                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                            fieldLabel(Copy.name)
                            UFitInput(Copy.name, text: $name).textContentType(.name)
                        }
                    }
                    if mode != .newPassword {
                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                            fieldLabel(identifierLabel)
                            UFitInput(identifierLabel, text: $email)
                                .textContentType(.emailAddress).keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                        }
                    }
                    if mode != .recovery {
                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                            fieldLabel(Copy.password)
                            UFitInput(mode == .signUp || mode == .newPassword ? Copy.passwordMinimum : Copy.password, text: $password, isSecure: true)
                                .textContentType(mode == .signIn ? .password : .newPassword)
                        }
                    }
                }.disabled(isBusy)
                }
                if let message {
                    UFitNotice(message: message, kind: messageKind).accessibilityAddTraits(.updatesFrequently)
                }
                UFitActionButton(title: actionTitle, isBusy: isBusy, disabled: !canSubmit, action: onSubmit)
                if mode == .signIn {
                    UFitButton { mode = .recovery; password = String() } label: {
                        Text(Copy.forgotten).font(UFitTypography.subheadline).underline()
                    }.disabled(isBusy)
                }
                if mode.awaitsEmail {
                    UFitActionButton(title: UFitAuthenticationCopy.changeEmail, kind: .secondary, disabled: isBusy) { mode = mode == .confirmEmail ? .signIn : .recovery }
                    if mode == .recoverySent { UFitActionButton(title: Copy.existing, kind: .secondary, disabled: isBusy) { mode = .signIn } }
                } else if mode != .newPassword {
                    UFitActionButton(title: mode == .signIn ? Copy.create : Copy.existing, kind: .secondary, disabled: isBusy) {
                        mode = mode == .signIn ? .signUp : .signIn
                        password = String()
                    }
                }
            }
            .ufitButtonStyle(.text)
            .foregroundStyle(Color.ufitInk)
            .padding(Layout.page)
        }
        .background(Color.ufitCanvas)
        .scrollDismissesKeyboard(.interactively)
        .id(mode)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.ufitCanvas)
    }
    private func back() {
        if mode == .newPassword { onCancelRecovery() }
        else if mode == .signIn || mode == .signUp { onBackToEntry() }
        else { mode = .signIn }
    }
    private func fieldLabel(_ label: String) -> some View {
        Text(label).font(UFitTypography.subheadline.weight(.medium))
    }
}
