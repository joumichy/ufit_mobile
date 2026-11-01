import SwiftUI

struct UFitMultilineField: View {
    let label: String
    @Binding var text: String
    var error: String?
    private enum Layout {
        static let gap: CGFloat = 8; static let inset: CGFloat = 16; static let radius: CGFloat = 12
        static let minimumLines = 4; static let maximumLines = 10
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(label).font(.subheadline.weight(.medium))
            TextField(label, text: $text, axis: .vertical).lineLimit(Layout.minimumLines...Layout.maximumLines)
                .textInputAutocapitalization(.sentences).padding(Layout.inset)
                .overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder) }.accessibilityLabel(label)
            if let error { Text(error).font(.caption) }
        }
    }
}
