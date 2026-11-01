import SwiftUI

struct OutfitPieceCard: View {
    let index: Int
    let piece: OutfitPiece

    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("#\(index)")
                        .ufitFont(size: UFitTypography.Size.small)
                        .foregroundStyle(Color.ufitSecondaryText)
                    Text(piece.name)
                        .ufitFont(size: UFitTypography.Size.body, weight: .medium)
                    Text(piece.brand)
                        .ufitFont(size: UFitTypography.Size.small)
                        .foregroundStyle(Color.ufitSecondaryText)
                }

                Spacer()

                Text(piece.price)
                    .ufitFont(size: UFitTypography.Size.section, weight: .regular)
            }

            FlowLayout(spacing: UFitSpace.xs) {
                ForEach(piece.sizes, id: \.self) { size in
                    Text(size)
                        .ufitFont(size: UFitTypography.Size.small, weight: .medium)
                        .foregroundStyle(Color.ufitInk)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 9)
                        .background(.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color.ufitBorder, lineWidth: 1)
                        )
                }
            }

            if !piece.isShoppable {
                Text("Inspiration only")
                    .ufitFont(size: UFitTypography.Size.caption, weight: .medium)
                    .foregroundStyle(Color.ufitSecondaryText)
            }
        }
        .padding(18)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card, style: .continuous))
    }
}
