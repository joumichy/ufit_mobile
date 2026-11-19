import SwiftUI

struct UFitCurrencySelectionContent: View {
    let currencies: [UFitCurrency]
    let selected: String
    let onSelect: (UFitCurrency) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        UFitSelectionList(title: String(localized: "Devise"), selection: Binding(get: { selected }, set: { value in
            if let item = currencies.first(where: { $0.code == value }) { onSelect(item); dismiss() }
        }), options: currencies.map { .init(value: $0.code, title: $0.code) }, onClose: { dismiss() })
    }
}
