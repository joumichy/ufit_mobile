import SwiftUI

struct RootScreenHeader: View {
    let title: String
    let subtitle: String?
    init(title: String, subtitle: String? = nil) { self.title = title; self.subtitle = subtitle }

    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            Text(title)
                .ufitFont(size: UFitTypography.Size.editorial, design: .serif)
                .foregroundStyle(Color.ufitInk).accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).ufitFont(size: UFitTypography.Size.small).foregroundStyle(Color.ufitSecondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, UFitSpace.xl)
        .padding(.top, UFitSpace.xl)
        .padding(.bottom, 18)
        .background(Color.ufitCanvas)
    }
}

struct SearchField: View {
    @Binding var query: String
    private enum Copy { static let prompt = String(localized: "Nom de tenue, créateur ou pièce") }
    var body: some View { UFitSearchField(query: $query, prompt: Copy.prompt).padding(.horizontal, UFitSpace.page) }
}
struct EmptySearchState: View {
    private enum Copy {
        static let title = String(localized: "Aucune tenue trouvée")
        static let message = String(localized: "Essayez un autre nom de tenue, de créateur ou de pièce.")
        static let symbol = "magnifyingglass"
    }
    var body: some View { UFitEmptyState(title: Copy.title, message: Copy.message, symbol: Copy.symbol).background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card)) }
}

struct WorkspaceEntryCard: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let primaryMetric: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            HStack(alignment: .top, spacing: UFitSpace.md) {
                UFitIcon(systemName: systemImage)
                    .ufitFont(size: UFitTypography.Size.section, weight: .medium)
                    .foregroundStyle(Color.ufitInk)
                    .frame(width: 44, height: 44)
                    .background(Color.ufitSecondary, in: Circle())

                VStack(alignment: .leading, spacing: UFitSpace.xs) {
                    Text(title)
                        .ufitFont(size: UFitTypography.Size.heading, weight: .semibold)
                        .foregroundStyle(Color.ufitInk)
                    Text(subtitle)
                        .ufitFont(size: UFitTypography.Size.small)
                        .foregroundStyle(Color.ufitSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack {
                Text(primaryMetric)
                    .ufitFont(size: UFitTypography.Size.small, weight: .medium)
                    .foregroundStyle(Color.ufitInk)
                    .padding(.horizontal, UFitSpace.sm)
                    .frame(height: 34)
                    .background(Color.ufitSecondary, in: Capsule())

                Spacer()

                UFitButton(action: action) {
                    HStack(spacing: UFitSpace.xs) {
                        Text(actionTitle)
                        UFitIcon(systemName: "chevron.right")
                            .ufitFont(size: UFitTypography.Size.caption, weight: .semibold)
                    }
                    .ufitFont(size: UFitTypography.Size.small, weight: .semibold)
                }
                .ufitButtonStyle(.primary, compact: true)
                .frame(width: 148)
            }
        }
        .padding(18)
        .background(Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: UFitRadius.card, style: .continuous)
                .stroke(Color.ufitBorder, lineWidth: 1)
        }
    }
}

struct WorkspaceNotice: View {
    let text: String

    var body: some View {
        Text(text)
            .ufitFont(size: UFitTypography.Size.small)
            .foregroundStyle(Color.ufitSecondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(UFitSpace.md)
            .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card, style: .continuous))
    }
}

struct SavedOutfitRow: View {
    let outfit: Outfit
    private enum Layout { static let imageWidth: CGFloat = 120; static let imageHeight: CGFloat = 160; static let imageRadius: CGFloat = 2 }
    var body: some View {
        VStack(spacing: UFitSpace.md) {
            HStack(alignment: .center, spacing: UFitSpace.md) {
                FashionImage(source: outfit.imageName).frame(width: Layout.imageWidth, height: Layout.imageHeight).clipped().clipShape(RoundedRectangle(cornerRadius: Layout.imageRadius)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: UFitSpace.xs) {
                    Text(outfit.creator).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    Text(outfit.title).ufitFont(size: UFitTypography.Size.section, design: .serif).foregroundStyle(Color.ufitInk).multilineTextAlignment(.leading)
                    Text(outfit.price).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText).multilineTextAlignment(.leading)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.vertical, UFitSpace.xxs)
            Rectangle().fill(Color.ufitBorder).frame(height: UFitSpace.hairline)
        }.accessibilityElement(children: .combine)
    }
}

struct EmptySavedState: View {
    let onBrowse: () -> Void
    private enum Copy {
        static let title = String(localized: "Aucune tenue enregistrée")
        static let message = String(localized: "Enregistrez une tenue avec le marque-page pour la retrouver ici.")
        static let browse = String(localized: "Découvrir les tenues")
        static let symbol = "bookmark"
    }
    var body: some View { UFitEmptyState(title: Copy.title, message: Copy.message, symbol: Copy.symbol, actionTitle: Copy.browse, actionKind: .primary, action: onBrowse).background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card)) }
}
