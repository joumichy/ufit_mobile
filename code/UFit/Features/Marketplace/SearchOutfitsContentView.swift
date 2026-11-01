import SwiftUI

struct SearchOutfitsContentView: View {
    let outfits: [Outfit]
    let onOutfitTap: (Outfit) -> Void

    @State private var query = ""
    @State private var selectedFilter = "All"

    private let filters = ["All", "Minimal", "Tailored", "Evening", "Layered"]

    private var filteredOutfits: [Outfit] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let selectedNeedle = selectedFilter.lowercased()

        return outfits.filter { outfit in
            let searchable = (
                [outfit.title, outfit.creator, outfit.description] +
                outfit.products.map(\.name) +
                outfit.pieces.map(\.name)
            )
            .joined(separator: " ")
            .lowercased()

            let matchesQuery = normalizedQuery.isEmpty || searchable.contains(normalizedQuery)
            let matchesFilter = selectedFilter == "All" || searchable.contains(selectedNeedle)
            return matchesQuery && matchesFilter
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            RootScreenHeader(title: "Search", subtitle: "Find outfits by creator, style, occasion, or piece.")

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SearchField(query: $query)

                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(filters, id: \.self) { filter in
                                Button {
                                    selectedFilter = filter
                                } label: {
                                    Text(filter)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(selectedFilter == filter ? .white : Color.ufitInk)
                                        .padding(.horizontal, 14)
                                        .frame(height: 36)
                                        .background(
                                            selectedFilter == filter ? Color.ufitInk : Color.white,
                                            in: Capsule()
                                        )
                                        .overlay {
                                            Capsule()
                                                .stroke(Color.ufitBorder, lineWidth: selectedFilter == filter ? 0 : 1)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .scrollIndicators(.hidden)

                    if filteredOutfits.isEmpty {
                        EmptySearchState()
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredOutfits) { outfit in
                                Button {
                                    onOutfitTap(outfit)
                                } label: {
                                    SavedOutfitRow(outfit: outfit)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 104)
            }
            .scrollIndicators(.hidden)
            .background(Color.white)
        }
        .background(Color.white)
    }
}
