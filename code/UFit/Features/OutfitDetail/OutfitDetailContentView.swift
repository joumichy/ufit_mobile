import SwiftUI

struct OutfitDetailContentView: View {
    let outfit: Outfit
    let pieces: [OutfitPiece]
    let onBack: () -> Void
    let onBuy: () -> Void

    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                HStack(spacing: UFitSpace.md) {
                    UFitIcon(systemName: "square.and.arrow.up")
                    UFitIcon(systemName: "heart")
                }
                .ufitFont(size: UFitTypography.Size.section, weight: .regular)
                .foregroundStyle(Color.ufitInk)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    OutfitHeroImage(imageName: outfit.imageName)
                    OutfitSummary(outfit: outfit)
                    OutfitPiecesSection(pieces: pieces)
                    CheckoutSummary(total: outfit.price)
                    UFitButton("Acheter le look complet", action: onBuy)
                        .ufitButtonStyle(.primary)
                        .padding(.horizontal, UFitSpace.xl)
                        .padding(.bottom, UFitSpace.xl)
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.ufitCanvas)
        }
        .background(Color.ufitCanvas)
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
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            Text(outfit.title)
                .ufitFont(size: UFitTypography.Size.title, weight: .regular)
            Text("By \(outfit.creator)")
                .ufitFont(size: UFitTypography.Size.body)
                .foregroundStyle(Color.ufitSecondaryText)
            Text(outfit.description)
                .ufitFont(size: UFitTypography.Size.small)
                .lineSpacing(3)
                .foregroundStyle(Color.ufitSecondaryText)
                .padding(.top, UFitSpace.xxs)
        }
        .padding(.horizontal, UFitSpace.xl)
    }
}

struct OutfitPiecesSection: View {
    let pieces: [OutfitPiece]

    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            Text("Complete the Look")
                .ufitFont(size: UFitTypography.Size.section, weight: .medium)
                .padding(.horizontal, UFitSpace.xl)

            ForEach(Array(pieces.enumerated()), id: \.element.id) { index, piece in
                OutfitPieceCard(index: index + 1, piece: piece)
                    .padding(.horizontal, UFitSpace.xl)
            }
        }
    }
}

struct CheckoutSummary: View {
    let total: String

    var body: some View {
        VStack(spacing: UFitSpace.sm) {
            HStack {
                Text("Subtotal")
                    .foregroundStyle(Color.ufitSecondaryText)
                Spacer()
                Text(total)
            }

            Divider()

            HStack {
                Text("Total")
                Spacer()
                Text(total)
                    .ufitFont(size: UFitTypography.Size.section, weight: .medium)
            }
        }
        .ufitFont(size: UFitTypography.Size.body)
        .foregroundStyle(Color.ufitInk)
        .padding(18)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card, style: .continuous))
        .padding(.horizontal, UFitSpace.xl)
    }
}
