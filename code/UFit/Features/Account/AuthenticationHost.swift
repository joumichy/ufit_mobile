import SwiftUI
import AuthenticationServices
import CryptoKit
import Security

struct UFitAuthenticationHost: View {
    let session: UFitSessionStore
    @State private var mode = UFitAuthenticationMode.signIn
    @State private var showsEntry = true
    @State private var name = String()
    @State private var email = String()
    @State private var password = String()
    @State private var appleNonce: String?
    @State private var appleError: String?

    var body: some View {
        Group {
            if showsEntry && !session.needsNewPassword {
                UFitAuthenticationEntryContent(message: appleError ?? session.message,
                    messageKind: appleError != nil || session.authenticationFailure != nil ? .error : .information,
                    onSignIn: { open(.signIn) }, onSignUp: { open(.signUp) })
            } else {
                form
            }
        }
            .onChange(of: session.needsNewPassword) { _, needed in
                if needed { mode = .newPassword; showsEntry = false }
                else if mode == .newPassword { mode = .recovery }
            }
            .onChange(of: mode) { _, _ in appleError = nil; appleNonce = nil; session.message = nil; password = String() }
            .onAppear { if session.needsNewPassword { mode = .newPassword; showsEntry = false } }
            .onDisappear { if session.authenticationFailure != nil { session.message = nil } }
    }

    private var form: some View {
        UFitAuthenticationView(mode: $mode, name: $name, email: $email, password: $password,
            isBusy: session.isBusy, message: appleError ?? session.message,
            messageKind: appleError != nil || session.authenticationFailure != nil ? .error : .information,
            onSubmit: { Task { await submit() } },
            onAppleRequest: prepareApple, onAppleComplete: completeApple,
            onCancelRecovery: { Task { await session.cancelPasswordRecovery() } },
            onBackToEntry: {
                password = String(); appleError = nil; appleNonce = nil; session.message = nil
                showsEntry = true
            })
    }
    private func open(_ destination: UFitAuthenticationMode) {
        mode = destination
        showsEntry = false
    }

    private func submit() async {
        appleError = nil
        switch mode {
        case .signIn:
            await session.signIn(email: email, password: password)
            if session.authenticationFailure == .unconfirmed { mode = .confirmEmail }
        case .signUp:
            if await session.signUp(email: email, password: password, name: name), !session.isSignedIn { mode = .confirmEmail }
        case .confirmEmail: _ = await session.resendConfirmation(email: email)
        case .recovery:
            if await session.resetPassword(email: email) { mode = .recoverySent }
        case .recoverySent:
            if await session.resetPassword(email: email) { session.message = UFitAuthenticationCopy.sentAgain }
        case .newPassword:
            _ = await session.updatePassword(password)
        }
    }

    private func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        appleError = nil; appleNonce = nil
        var bytes = [UInt8](repeating: .zero, count: UFitAuthenticationCallback.nonceLength)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            appleError = UFitSessionError.invalidAppleCredential.localizedDescription
            return
        }
        let nonce = Data(bytes).base64EncodedString()
        appleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: UFitAuthenticationCallback.hexadecimalByte, $0) }.joined()
    }

    private func completeApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
                  let nonce = appleNonce else {
                appleError = UFitSessionError.invalidAppleCredential.localizedDescription
                return
            }
            appleNonce = nil
            Task { await session.signInWithApple(idToken: token, nonce: nonce) }
        case .failure(let error):
            appleNonce = nil
            if (error as? ASAuthorizationError)?.code != .canceled { appleError = UFitAuthenticationCopy.appleFailed }
        }
    }
}
