import SwiftUI
import AuthenticationServices
import PhotosUI
import SafariServices

/// Apple owns this required identity interface; its permitted black variant matches Onyx.
struct UFitAppleSignIn: View {
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    var body: some View {
        SignInWithAppleButton(.continue, onRequest: onRequest, onCompletion: onCompletion)
            .signInWithAppleButtonStyle(.black).frame(height: UFitControlSize.input)
            .clipShape(RoundedRectangle(cornerRadius: UFitRadius.field))
    }
}

/// Photos owns permissions and picking; Ufit restricts this boundary to ordered images.
extension View {
    func ufitPhotosPicker(isPresented: Binding<Bool>, selection: Binding<[PhotosPickerItem]>, limit: Int) -> some View {
        photosPicker(isPresented: isPresented, selection: selection, maxSelectionCount: limit, selectionBehavior: .ordered, matching: .images, preferredItemEncoding: .current)
    }
}
struct UFitStripeBrowser: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(Color.ufitInk)
        controller.preferredBarTintColor = UIColor(Color.ufitCanvas)
        return controller
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct UFitLink<Label: View>: View {
    let destination: URL
    let label: Label
    @Environment(\.openURL) private var openURL
    init(destination: URL, @ViewBuilder label: () -> Label) { self.destination = destination; self.label = label() }
    var body: some View { UFitButton { openURL(destination) } label: { label }.ufitButtonStyle(.text) }
}
extension UFitLink where Label == Text {
    init(_ title: String, destination: URL) { self.init(destination: destination) { Text(title) } }
}
