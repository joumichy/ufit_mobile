import SwiftUI

struct SavedOutfitsContentView: View {
    let outfits: [Outfit]
    let onOutfitTap: (Outfit) -> Void

    var body: some View {
        VStack(spacing: 0) {
            RootScreenHeader(title: "Saved", subtitle: "Curated looks you kept for later.")

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if outfits.isEmpty {
                        EmptySavedState()
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(outfits) { outfit in
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
