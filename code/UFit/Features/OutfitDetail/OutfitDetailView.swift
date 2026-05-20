import SwiftUI

struct OutfitDetailView: View {
    let outfit: Outfit
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(onBack: onBack) {
                HStack(spacing: 18) {
                    Image(systemName: "square.and.arrow.up")
                    Image(systemName: "heart")
                }
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(Color.ufitInk)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    OutfitHeroImage(imageName: outfit.imageName)
                    OutfitSummary(outfit: outfit)
                    OutfitPiecesSection(pieces: SampleData.outfitPieces)
                    CheckoutSummary()
                    Button("Acheter le look complet") {}
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 24)
                        .padding(.bottom, 104)
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.white)
        }
        .background(Color.white)
    }
}

private struct OutfitHeroImage: View {
    let imageName: String

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fill)
            .clipped()
            .background(Color.ufitSecondary)
    }
}

private struct OutfitSummary: View {
    let outfit: Outfit

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(outfit.title)
                .font(.system(size: 27, weight: .regular))
            Text("By \(outfit.creator)")
                .font(.system(size: 15))
                .foregroundStyle(Color.ufitMuted)
            Text("Effortless elegance meets street style. A carefully curated selection of premium pieces from independent European ateliers.")
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundStyle(Color.ufitMuted)
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }
}

private struct OutfitPiecesSection: View {
    let pieces: [OutfitPiece]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Complete the Look")
                .font(.system(size: 20, weight: .medium))
                .padding(.horizontal, 24)

            ForEach(Array(pieces.enumerated()), id: \.element.id) { index, piece in
                OutfitPieceCard(index: index + 1, piece: piece)
                    .padding(.horizontal, 24)
            }
        }
    }
}

private struct CheckoutSummary: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Subtotal")
                    .foregroundStyle(Color.ufitMuted)
                Spacer()
                Text("449€")
            }

            Divider()

            HStack {
                Text("Total")
                Spacer()
                Text("449€")
                    .font(.system(size: 22, weight: .medium))
            }
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.ufitInk)
        .padding(18)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }
}

#Preview {
    OutfitDetailView(outfit: SampleData.outfits[0], onBack: {})
}
