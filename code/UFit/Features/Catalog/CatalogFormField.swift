import SwiftUI

struct UFitCatalogTextField: View {
    let label: String
    @Binding var text: String
    var error: String?
    var keyboard: UIKeyboardType = .default
    var isIdentifier = false
    private enum Layout { static let gap: CGFloat = 8; static let inset: CGFloat = 16; static let height: CGFloat = 48; static let radius: CGFloat = 12 }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(label).font(.subheadline.weight(.medium))
            TextField(label, text: $text).keyboardType(keyboard)
                .textInputAutocapitalization(isIdentifier ? .never : .sentences).autocorrectionDisabled(isIdentifier)
                .padding(.horizontal, Layout.inset).frame(minHeight: Layout.height)
                .overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder) }.accessibilityLabel(label)
            if let error { Text(error).font(.caption) }
        }
    }
}
struct UFitCatalogCurrencyContent: View {
    let currencies: [UFitCatalogCurrency]
    let selected: String
    let onSelect: (UFitCatalogCurrency) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = String()
    private enum Copy { static let title = String(localized: "Devise"); static let search = String(localized: "Rechercher une devise"); static let close = String(localized: "Fermer"); static let checkmark = "checkmark"; static let noResults = String(localized: "Aucune devise correspondante") }
    private enum Layout { static let touch: CGFloat = 44 }
    private var filtered: [UFitCatalogCurrency] { currencies.filter { search.isEmpty || $0.code.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty { Text(Copy.noResults).foregroundStyle(Color.ufitMuted) }
                ForEach(filtered) { currency in
                    Button { onSelect(currency); dismiss() } label: {
                        HStack { Text(currency.code); Spacer(); if currency.code == selected { Image(systemName: Copy.checkmark) } }.frame(minHeight: Layout.touch)
                    }.foregroundStyle(Color.ufitInk)
                }
            }.searchable(text: $search, prompt: Copy.search).navigationTitle(Copy.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(Copy.close) { dismiss() } } }
        }.tint(Color.ufitInk)
    }
}
