import SwiftUI

struct OutfitFeedCard: View {
    let outfit: Outfit
    let isLiked: Bool
    let onLike: () -> Void
    let onOutfitTap: () -> Void
    let onCreatorTap: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image(outfit.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
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
        .clipped()
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
        .padding(.bottom, 132)
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

            Button(action: onOutfitTap) {
                Text(outfit.title)
                    .font(.system(size: 22, weight: .medium))
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(outfit.title)")
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
            ProductShortcutList(outfitID: outfit.id, products: outfit.products)
                .id(outfit.id)

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
    let outfitID: Int
    let products: [OutfitProduct]

    @State private var isExpanded = false
    @State private var isContentVisible = false
    @State private var presentationToken = UUID()

    private var expandedHeight: CGFloat {
        let iconHeight: CGFloat = 50
        let spacing: CGFloat = 11
        let totalHeight = CGFloat(products.count) * iconHeight + CGFloat(max(products.count - 1, 0)) * spacing
        return min(totalHeight, 320)
    }

    var body: some View {
        VStack(spacing: 11) {
            if isExpanded {
                ScrollView(.vertical) {
                    VStack(spacing: 11) {
                        ForEach(products) { product in
                            CircularIconButton(systemImage: product.systemImage, accessibilityLabel: product.name)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(height: expandedHeight)
                .opacity(isContentVisible ? 1 : 0)
                .scaleEffect(isContentVisible ? 1 : 0.96, anchor: .bottom)
                .accessibilityHidden(!isContentVisible)
            }

            Button(action: toggleExpanded) {
                CircularIconButton(
                    systemImage: "tshirt",
                    accessibilityLabel: isExpanded ? "Hide outfit pieces" : "Show outfit pieces"
                )
            }
            .buttonStyle(.plain)
        }
        .frame(width: 50)
        .onChange(of: outfitID) { _, _ in
            resetPresentation()
        }
    }

    private func toggleExpanded() {
        if products.isEmpty || isExpanded {
            collapse()
        } else {
            expand()
        }
    }

    private func resetPresentation() {
        presentationToken = UUID()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isExpanded = false
            isContentVisible = false
        }
    }

    private func expand() {
        let token = UUID()
        presentationToken = token

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isExpanded = true
            isContentVisible = false
        }

        Task { @MainActor in
            await Task.yield()
            guard presentationToken == token, isExpanded else { return }
            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                isContentVisible = true
            }
        }
    }

    private func collapse() {
        let token = UUID()
        presentationToken = token

        withAnimation(.easeOut(duration: 0.14)) {
            isContentVisible = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard presentationToken == token else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isExpanded = false
            }
        }
    }
}
