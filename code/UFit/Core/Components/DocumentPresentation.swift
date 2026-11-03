import SwiftUI
import UniformTypeIdentifiers
import QuickLook

extension View {
    func ufitDocumentImporter(isPresented: Binding<Bool>, onResult: @escaping (Result<URL, Error>) -> Void) -> some View {
        fileImporter(isPresented: isPresented, allowedContentTypes: [.pdf, .jpeg], onCompletion: onResult)
    }
    func ufitDocumentPreview(_ url: Binding<URL?>) -> some View {quickLookPreview(url)}
}
