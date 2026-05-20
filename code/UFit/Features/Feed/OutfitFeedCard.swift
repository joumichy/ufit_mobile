import SwiftUI

struct OutfitFeedCard: View {
    let outfit: Outfit
    let isLiked: Bool
    let viewportSize: CGSize
    let onLike: () -> Void
    let onOutfitTap: () -> Void
    let onCreatorTap: () -> Void

    var body: some View {
        ZStack {
            Image(outfit.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: viewportSize.width, height: viewportSize.height)
                .clipped()

            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )

            OutfitFeedOverlay(
                outfit: outfit,
                isLiked: isLiked,
                onLike: onLike,
                onOutfitTap: onOutfitTap,
                onCreatorTap: onCreatorTap
            )
        }
    }
}

private struct OutfitFeedOverlay: View {
    let outfit: Outfit
    let isLiked: Bool
    let onLike: () -> Void
    let onOutfitTap: () -> Void
    let onCreatorTap: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            OutfitFeedCaption(
                outfit: outfit,
                onOutfitTap: onOutfitTap,
                onCreatorTap: onCreatorTap
            )

            Spacer(minLength: 8)

            OutfitFeedActions(outfit: outfit, isLiked: isLiked, onLike: onLike)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 116)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

private struct OutfitFeedCaption: View {
    let outfit: Outfit
    let onOutfitTap: () -> Void
    let onCreatorTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onCreatorTap) {
                HStack(spacing: 12) {
                    CreatorAvatar(initials: outfit.creatorAvatar)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(outfit.creator)
                            .font(.system(size: 15, weight: .medium))
                        Text("Creator")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 10) {
                Text(outfit.title)
                    .font(.system(size: 22, weight: .medium))

                Button(action: onOutfitTap) {
                    HStack(spacing: 8) {
                        Text("Voir le look")
                        Text(outfit.price)
                            .foregroundStyle(.black.opacity(0.68))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
    }
}

private struct CreatorAvatar: View {
    let initials: String

    var body: some View {
        Text(initials)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.white.opacity(0.18), in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
    }
}

private struct OutfitFeedActions: View {
    let outfit: Outfit
    let isLiked: Bool
    let onLike: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ProductShortcutList(products: outfit.products)

            Button(action: onLike) {
                VStack(spacing: 5) {
                    CircularIconButton(
                        systemImage: isLiked ? "heart.fill" : "heart",
                        accessibilityLabel: "Like outfit"
                    )
                    Text("\(outfit.likes + (isLiked ? 1 : 0))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 5) {
                CircularIconButton(systemImage: "bubble.right", accessibilityLabel: "Comments")
                Text("\(outfit.comments)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct ProductShortcutList: View {
    let products: [OutfitProduct]

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 11) {
                ForEach(products) { product in
                    CircularIconButton(systemImage: product.systemImage, accessibilityLabel: product.name)
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: 204)
    }
}
