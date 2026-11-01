import SwiftUI

struct OutfitDetailContentView: View {
    let outfit: Outfit
    let pieces: [OutfitPiece]
    let onBack: () -> Void
    let onBuy: () -> Void

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
                    OutfitPiecesSection(pieces: pieces)
                    CheckoutSummary(total: outfit.price)
                    Button("Acheter le look complet", action: onBuy)
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

struct OutfitHeroImage: View {
    let imageName: String

    var body: some View {
        FashionImage(source: imageName)
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fill)
            .clipped()
            .background(Color.ufitSecondary)
    }
}

struct OutfitSummary: View {
    let outfit: Outfit

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(outfit.title)
                .font(.system(size: 27, weight: .regular))
            Text("By \(outfit.creator)")
                .font(.system(size: 15))
                .foregroundStyle(Color.ufitMuted)
            Text(outfit.description)
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundStyle(Color.ufitMuted)
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }
}

struct OutfitPiecesSection: View {
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

struct CheckoutSummary: View {
    let total: String

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Subtotal")
                    .foregroundStyle(Color.ufitMuted)
                Spacer()
                Text(total)
            }

            Divider()

            HStack {
                Text("Total")
                Spacer()
                Text(total)
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
