import SwiftUI

struct UFitPublicProfileContent: View {
    let profile: UFitPublicProfilePresentation?
    let outfits: [UFitPublicOutfitTile]
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMore: Bool
    let followState: UFitPublicFollowState
    let isFollowingBusy: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () async -> Void
    let onMore: () -> Void
    let onFollow: () -> Void
    let onRetryFollow: () -> Void
    let onOpen: (String) -> Void
    private enum Copy {
        static let title = String(localized: "Profil"); static let refresh = String(localized: "Actualiser le profil")
        static let loading = String(localized: "Chargement du profil"); static let retry = String(localized: "Réessayer")
        static let creator = String(localized: "Créateur Ufit"); static let brand = String(localized: "Marque")
        static let follow = String(localized: "Suivre"); static let unfollow = String(localized: "Ne plus suivre")
        static let followLoading = String(localized: "Chargement du suivi"); static let following = String(localized: "Mise à jour du suivi")
        static let followRetry = String(localized: "Réessayer le suivi")
        static let outfits = String(localized: "Les tenues"); static let empty = String(localized: "Aucune tenue publiée pour le moment.")
        static let more = String(localized: "Voir plus de tenues"); static let at = "@"; static let separator = ", "
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch
        static let avatar: CGFloat = 80; static let title: CGFloat = UFitTypography.Size.editorial; static let tileAspect: CGFloat = 0.75; static let bottom: CGFloat = 112
        static let initial: CGFloat = UFitTypography.Size.section; static let columns = [GridItem(.flexible(), spacing: gap), GridItem(.flexible(), spacing: gap)]
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let grade = "medal"; static let link = "arrow.up.right" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                if isLoading { UFitLoading().frame(width: Layout.touch, height: Layout.touch) }
                else { UFitButton { Task { await onRefresh() } } label: { UFitIcon(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if let message { Text(message).font(UFitTypography.callout) }
                    if let profile {
                        header(profile)
                        follow
                        if let bio = profile.bio, !bio.isEmpty { Text(bio).font(UFitTypography.body).foregroundStyle(Color.ufitSecondaryText) }
                        if !profile.stats.isEmpty {
                            HStack(spacing: Layout.small) {
                                ForEach(profile.stats) { stat in
                                    CreatorStatCard(icon: stat.icon, value: stat.value.formatted(), label: stat.label)
                                        .accessibilityElement(children: .ignore).accessibilityLabel(stat.label + Copy.separator + stat.value.formatted())
                                }
                            }
                        }
                        if !profile.links.isEmpty {
                            VStack(alignment: .leading, spacing: Layout.small) {
                                ForEach(profile.links) { link in
                                    if let destination = link.destination { UFitLink(destination: destination) { Label(link.label, systemImage: Icon.link).frame(minHeight: Layout.touch) } }
                                    else { Text(link.label).font(UFitTypography.callout).frame(minHeight: Layout.touch) }
                                }
                            }
                        }
                        Text(Copy.outfits).font(UFitTypography.title2.weight(.medium))
                        if outfits.isEmpty && !isLoading && message == nil { Text(Copy.empty).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                        LazyVGrid(columns: Layout.columns, alignment: .leading, spacing: Layout.page) {
                            ForEach(outfits) { outfit in
                                UFitButton { onOpen(outfit.id) } label: {
                                    VStack(alignment: .leading, spacing: Layout.small) {
                                        Color.ufitSecondary.aspectRatio(Layout.tileAspect, contentMode: .fit).overlay { FashionImage(source: outfit.image) }.clipped()
                                        Text(outfit.title).font(UFitTypography.subheadline.weight(.medium)).lineLimit(2)
                                        Text(outfit.price).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.ufitButtonStyle(.text).accessibilityLabel(outfit.title + Copy.separator + outfit.price)
                            }
                        }
                        if isLoadingMore { UFitLoading().frame(maxWidth: .infinity) }
                        else if hasMore { UFitActionButton(title: Copy.more, kind: .secondary, action: onMore) }
                    } else if isLoading { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                    else { UFitButton { Task { await onRefresh() } } label: { Text(Copy.retry).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary) }
                }.padding(Layout.page).padding(.bottom, UFitSpace.xl)
            }.ufitRefreshable { await onRefresh() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func header(_ profile: UFitPublicProfilePresentation) -> some View {
        HStack(alignment: .top, spacing: Layout.gap) {
            Group {
                if let avatar = profile.avatarURL {
                    UFitProfilePhoto(source: avatar, size: Layout.avatar, isLogo: profile.reference.kind == .brand, onRetry: onRefresh)
                }
                else { Text(profile.initials).ufitFont(size: Layout.initial, weight: .medium).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.ufitSecondary) }
            }.frame(width: Layout.avatar, height: Layout.avatar).clipShape(RoundedRectangle(cornerRadius: profile.reference.kind == .brand ? UFitRadius.field : Layout.avatar))
            VStack(alignment: .leading, spacing: Layout.small) {
                Text(profile.reference.kind == .creator ? Copy.creator : Copy.brand).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                Text(profile.name).ufitFont(size: Layout.title, design: .serif).fixedSize(horizontal: false, vertical: true)
                Text(Copy.at + profile.slug).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                if let grade = profile.grade { Label(grade, systemImage: Icon.grade).font(UFitTypography.caption.weight(.medium)) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder private var follow: some View {
        switch followState {
        case .hidden: EmptyView()
        case .loading: UFitLoading(Copy.followLoading)
        case .signIn: UFitButton(action: onFollow) { Text(Copy.follow).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary)
        case .ready(let following):
            UFitButton(action: onFollow) {
                HStack { Spacer(); if isFollowingBusy { UFitLoading(Copy.following).tint(.white) } else { Text(following ? Copy.unfollow : Copy.follow) }; Spacer() }
            }.ufitButtonStyle(.primary).disabled(isFollowingBusy)
        case .failed(let message):
            VStack(alignment: .leading, spacing: Layout.small) { Text(message).font(UFitTypography.caption); UFitActionButton(title: Copy.followRetry, kind: .secondary, action: onRetryFollow) }
        }
    }
}
