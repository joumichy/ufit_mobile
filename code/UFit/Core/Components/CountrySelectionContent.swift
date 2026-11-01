import SwiftUI

struct UFitCountrySelectionContent: View {
    let countries: [UFitCountry]
    let selected: String
    let onSelect: (UFitCountry) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        UFitSelectionList(title: String(localized: "Pays de livraison"), selection: Binding(get: { selected }, set: { value in
            if let item = countries.first(where: { $0.id == value }) { onSelect(item); dismiss() }
        }), options: countries.map { .init(value: $0.id, title: $0.name + CountryCopy.separator + $0.id) }, onClose: { dismiss() })
    }
}

private enum CountryCopy { static let separator = " · " }
