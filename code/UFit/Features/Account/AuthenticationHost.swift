import SwiftUI
import AuthenticationServices
import CryptoKit
import Security

struct UFitAuthenticationHost: View {
    let session: UFitSessionStore
    let onBrowse: () -> Void
    @State private var mode = UFitAuthenticationMode.signIn
    @State private var name = String()
    @State private var email = String()
    @State private var password = String()
    @State private var appleNonce: String?
    @State private var appleError: String?

    var body: some View {
        UFitAuthenticationView(mode: $mode, name: $name, email: $email, password: $password,
            isBusy: session.isBusy, message: appleError ?? session.message,
            onSubmit: { Task { await submit() } },
            onAppleRequest: prepareApple, onAppleComplete: completeApple, onBrowse: onBrowse)
            .onChange(of: session.needsNewPassword) { _, needed in
                if needed { mode = .newPassword }
            }
            .onChange(of: session.user?.id) { _, userID in
                if userID != nil && !session.needsNewPassword { onBrowse() }
            }
            .onAppear { if session.needsNewPassword { mode = .newPassword } }
            .task {
                if session.isSignedIn && session.user == nil { await session.reloadProfile() }
            }
    }

    private func submit() async {
        appleError = nil
        switch mode {
        case .signIn: await session.signIn(email: email, password: password)
        case .signUp: await session.signUp(email: email, password: password, name: name)
        case .recovery: await session.resetPassword(email: email)
        case .newPassword: await session.updatePassword(password)
        }
    }

    private func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        let nonceLength = 32
        var bytes = [UInt8](repeating: .zero, count: nonceLength)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            appleError = UFitSessionError.invalidAppleCredential.localizedDescription
            return
        }
        let nonce = Data(bytes).base64EncodedString()
        appleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        let hexadecimalFormat = "%02x"
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: hexadecimalFormat, $0) }.joined()
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
            if (error as? ASAuthorizationError)?.code != .canceled { appleError = error.localizedDescription }
        }
    }
}
