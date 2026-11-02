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
    let onBrowse: () -> Void

    private enum Copy {
        static let brand = "UFIT"
        static let close = String(localized: "Fermer")
        static let closeIcon = "xmark"
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

    var body: some View {
        VStack(spacing: .zero) {
        HStack {
            Spacer(minLength: .zero)
            UFitButton(action: onBrowse) { UFitIcon(systemName: Copy.closeIcon).font(UFitTypography.body) }
                .ufitButtonStyle(.text).accessibilityLabel(Copy.close).disabled(isBusy)
        }.padding(.horizontal, Layout.page).padding(.top, UFitSpace.sm)
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.spacing) {
                Text(Copy.brand).ufitFont(size: Layout.logoSize, weight: .semibold).tracking(Layout.tracking)
                Text(mode.title)
                    .ufitFont(size: Layout.titleSize, weight: .regular, design: .serif)
                    .accessibilityAddTraits(.isHeader)
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
                if mode.awaitsEmail {
                    Text(mode == .confirmEmail ? UFitAuthenticationCopy.confirmationDetail : UFitAuthenticationCopy.recoveryDetail)
                        .font(UFitTypography.body)
                    Text(email.trimmingCharacters(in: .whitespacesAndNewlines)).font(UFitTypography.headline)
                } else {
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
                }
                if let message {
                    UFitNotice(message: message, kind: messageKind).accessibilityAddTraits(.updatesFrequently)
                }
                UFitActionButton(title: actionTitle, isBusy: isBusy, disabled: !canSubmit, action: onSubmit)
                if mode == .signIn {
                    UFitButton(Copy.forgotten) { mode = .recovery; password = String() }.disabled(isBusy)
                }
                if mode.awaitsEmail {
                    UFitButton(UFitAuthenticationCopy.changeEmail) { mode = mode == .confirmEmail ? .signIn : .recovery }.disabled(isBusy)
                    if mode == .recoverySent { UFitButton(Copy.existing) { mode = .signIn }.disabled(isBusy) }
                } else if mode != .newPassword {
                    UFitButton(mode == .signIn ? Copy.create : Copy.existing) {
                        mode = mode == .signIn ? .signUp : .signIn
                        password = String()
                    }.disabled(isBusy)
                }
                UFitButton(mode == .newPassword ? UFitAuthenticationCopy.cancelRecovery : Copy.browse, action: onBrowse)
                    .foregroundStyle(Color.ufitSecondaryText).disabled(isBusy)
            }
            .ufitButtonStyle(.text)
            .foregroundStyle(Color.ufitInk)
            .padding(Layout.page)
        }
        .background(Color.ufitCanvas)
        .scrollDismissesKeyboard(.interactively)
        .id(mode)
        }
    }
    private func fieldLabel(_ label: String) -> some View {
        Text(label).font(UFitTypography.subheadline.weight(.medium))
    }
}
