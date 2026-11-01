import SwiftUI

struct UFitCountrySelectionContent: View {
    let countries: [UFitCountry]
    let selected: String
    let onSelect: (UFitCountry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = String()
    private enum Copy {
        static let title = String(localized: "Pays de livraison"); static let search = String(localized: "Rechercher un pays")
        static let close = String(localized: "Fermer"); static let empty = String(localized: "Aucun pays correspondant")
    }
    private enum Layout { static let touch: CGFloat = 44 }
    private enum Icon { static let check = "checkmark" }
    private var filtered: [UFitCountry] { countries.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty { Text(Copy.empty).foregroundStyle(Color.ufitMuted) }
                ForEach(filtered) { country in
                    Button { onSelect(country); dismiss() } label: {
                        HStack { Text(country.name); Spacer(); if country.id == selected { Image(systemName: Icon.check) } }.frame(minHeight: Layout.touch)
                    }.foregroundStyle(Color.ufitInk)
                }
            }.searchable(text: $search, prompt: Copy.search).navigationTitle(Copy.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(Copy.close) { dismiss() } } }
        }.tint(Color.ufitInk)
    }
}
