import SwiftUI

struct OutfitPieceCard: View {
    let index: Int
    let piece: OutfitPiece

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("#\(index)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.ufitMuted)
                    Text(piece.name)
                        .font(.system(size: 16, weight: .medium))
                    Text(piece.brand)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.ufitMuted)
                }

                Spacer()

                Text(piece.price)
                    .font(.system(size: 20, weight: .regular))
            }

            FlowLayout(spacing: 8) {
                ForEach(piece.sizes, id: \.self) { size in
                    Text(size)
                        .font(.system(size: 14, weight: .medium))
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.ufitMuted)
            }
        }
        .padding(18)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
