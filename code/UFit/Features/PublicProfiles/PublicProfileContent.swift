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
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44
        static let avatar: CGFloat = 80; static let title: CGFloat = 32; static let tileAspect: CGFloat = 0.75; static let bottom: CGFloat = 112
        static let initial: CGFloat = 24; static let columns = [GridItem(.flexible(), spacing: gap), GridItem(.flexible(), spacing: gap)]
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let grade = "medal"; static let link = "arrow.up.right" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                if isLoading { ProgressView().frame(width: Layout.touch, height: Layout.touch) }
                else { Button { Task { await onRefresh() } } label: { Image(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if let message { Text(message).font(.callout) }
                    if let profile {
                        header(profile)
                        follow
                        if let bio = profile.bio, !bio.isEmpty { Text(bio).font(.body).foregroundStyle(Color.ufitMuted) }
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
                                    if let destination = link.destination { Link(destination: destination) { Label(link.label, systemImage: Icon.link).frame(minHeight: Layout.touch) } }
                                    else { Text(link.label).font(.callout).frame(minHeight: Layout.touch) }
                                }
                            }
                        }
                        Text(Copy.outfits).font(.title2.weight(.medium))
                        if outfits.isEmpty && !isLoading { Text(Copy.empty).font(.callout).foregroundStyle(Color.ufitMuted) }
                        LazyVGrid(columns: Layout.columns, alignment: .leading, spacing: Layout.page) {
                            ForEach(outfits) { outfit in
                                Button { onOpen(outfit.id) } label: {
                                    VStack(alignment: .leading, spacing: Layout.small) {
                                        Color.ufitSecondary.aspectRatio(Layout.tileAspect, contentMode: .fit).overlay { FashionImage(source: outfit.image) }.clipped()
                                        Text(outfit.title).font(.subheadline.weight(.medium)).lineLimit(2)
                                        Text(outfit.price).font(.caption).foregroundStyle(Color.ufitMuted)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain).accessibilityLabel(outfit.title + Copy.separator + outfit.price)
                            }
                        }
                        if isLoadingMore { ProgressView().frame(maxWidth: .infinity) }
                        else if hasMore { Button(Copy.more, action: onMore).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                    } else if isLoading { ProgressView(Copy.loading).frame(maxWidth: .infinity) }
                    else { Button { Task { await onRefresh() } } label: { Text(Copy.retry).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()) }
                }.padding(Layout.page).padding(.bottom, Layout.bottom)
            }.refreshable { await onRefresh() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
    private func header(_ profile: UFitPublicProfilePresentation) -> some View {
        HStack(alignment: .top, spacing: Layout.gap) {
            Group {
                if let avatar = profile.avatarURL { FashionImage(source: avatar) }
                else { Text(profile.initials).font(.system(size: Layout.initial, weight: .medium)).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.ufitSecondary) }
            }.frame(width: Layout.avatar, height: Layout.avatar).clipShape(Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Layout.small) {
                Text(profile.reference.kind == .creator ? Copy.creator : Copy.brand).font(.caption).foregroundStyle(Color.ufitMuted)
                Text(profile.name).font(.system(size: Layout.title, design: .serif)).fixedSize(horizontal: false, vertical: true)
                Text(Copy.at + profile.slug).font(.caption).foregroundStyle(Color.ufitMuted)
                if let grade = profile.grade { Label(grade, systemImage: Icon.grade).font(.caption.weight(.medium)) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder private var follow: some View {
        switch followState {
        case .hidden: EmptyView()
        case .loading: ProgressView(Copy.followLoading)
        case .signIn: Button(action: onFollow) { Text(Copy.follow).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle())
        case .ready(let following):
            Button(action: onFollow) {
                HStack { Spacer(); if isFollowingBusy { ProgressView(Copy.following).tint(.white) } else { Text(following ? Copy.unfollow : Copy.follow) }; Spacer() }
            }.buttonStyle(PrimaryButtonStyle()).disabled(isFollowingBusy)
        case .failed(let message):
            VStack(alignment: .leading, spacing: Layout.small) { Text(message).font(.caption); Button(Copy.followRetry, action: onRetryFollow).frame(minHeight: Layout.touch) }
        }
    }
}
