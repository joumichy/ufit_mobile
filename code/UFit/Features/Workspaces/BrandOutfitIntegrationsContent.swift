import SwiftUI

struct UFitBrandOutfitIntegrationsHost: View {
    @Bindable var store: UFitBrandOutfitIntegrationsStore
    let onBack: () -> Void
    let onOutfit: (Outfit) -> Void
    private enum Copy {
        static let title = String(localized: "Vos pièces en tenue")
        static let refresh = String(localized: "Actualiser les intégrations")
        static let loading = String(localized: "Recherche des tenues")
        static let unavailable = String(localized: "Tenues indisponibles")
        static let access = String(localized: "Accès à la marque indisponible")
        static let retry = String(localized: "Réessayer")
        static let retryPage = String(localized: "Réessayer cette page")
        static let empty = String(localized: "Aucune tenue pour le moment")
        static let emptyMessage = String(localized: "Les tenues publiées contenant vos produits apparaîtront ici.")
        static let pieces = String(localized: "Vos pièces dans cette tenue")
        static let more = String(localized: "Charger la suite")
        static let archived = String(localized: "Produit archivé")
        static let draft = String(localized: "Produit en brouillon")
        static func open(_ title: String) -> String { String(localized: "Voir la tenue \(title)") }
        static func author(_ name: String) -> String { String(localized: "Par \(name)") }
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let failure = "wifi.exclamationmark"; static let access = "lock"; static let empty = "square.stack"; static let next = "arrow.up.right" }
    private enum Layout { static let cover: CGFloat = 260; static let state: CGFloat = 240 }
    private enum Anchor { static let nextPage = "brand-integrations-next-page" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                UFitButton { Task { await store.load() } } label: {
                    if store.operation == .refreshing { UFitLoading() }
                    else { UFitIcon(systemName: Icon.refresh) }
                }.frame(width: UFitControlSize.touch, height: UFitControlSize.touch)
                    .accessibilityLabel(Copy.refresh).disabled(store.isBusy || store.accessRevoked || !store.canRead)
            }
            if !store.entries.isEmpty, !store.failureAtEnd, let message = store.message {
                VStack(spacing: UFitSpace.sm) {
                    UFitNotice(message: message, kind: .error)
                    UFitActionButton(title: Copy.retry, kind: .secondary) { Task { await store.retry() } }
                }.padding(UFitSpace.page)
            }
            ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    Text(store.workspace.name).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    if store.entries.isEmpty {
                        if store.operation == .loading {
                            UFitLoading(Copy.loading).frame(maxWidth: .infinity, minHeight: Layout.state)
                        } else if let message = store.message {
                            UFitEmptyState(title: store.accessRevoked || !store.canRead ? Copy.access : Copy.unavailable,
                                message: message, symbol: store.accessRevoked || !store.canRead ? Icon.access : Icon.failure,
                                actionTitle: store.accessRevoked || !store.canRead ? nil : Copy.retry,
                                action: { Task { await store.retry() } })
                        } else if store.hasLoaded {
                            UFitEmptyState(title: Copy.empty, message: Copy.emptyMessage, symbol: Icon.empty)
                        }
                    }
                    LazyVStack(alignment: .leading, spacing: UFitSpace.xl) {
                        ForEach(store.entries) { entry in
                            VStack(alignment: .leading, spacing: UFitSpace.xl) {
                                entryContent(entry)
                                Divider()
                            }.id(entry.id)
                        }
                    }.scrollTargetLayout()
                    VStack(spacing: UFitSpace.md) {
                        if store.failureAtEnd, let message = store.message {
                            UFitNotice(message: message, kind: .error)
                            UFitActionButton(title: store.retriesNextPage ? Copy.retryPage : Copy.refresh, kind: .secondary) {
                                Task { await store.retry() }
                            }
                        } else if store.hasMore {
                            UFitActionButton(title: Copy.more, kind: .secondary, isBusy: store.operation == .more) {
                                Task { await store.load(more: true) }
                            }
                        }
                    }.id(Anchor.nextPage)
                }.padding(.vertical, UFitSpace.page)
            }.padding(.horizontal, UFitSpace.page).scrollPosition(id: $store.visibleEntryID, anchor: .top)
                .onChange(of: store.failureAtEnd) { _, failed in
                    if failed { scroll.scrollTo(Anchor.nextPage, anchor: .bottom) }
                }
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .task { if !store.hasLoaded { await store.load() } }.onDisappear { store.cancelLoading() }
    }
    private func entryContent(_ entry: UFitBrandOutfitIntegration) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            UFitButton { onOutfit(entry.outfit.toOutfit()) } label: {
                VStack(alignment: .leading, spacing: UFitSpace.md) {
                    GeometryReader { geometry in
                        FashionImage(source: entry.outfit.coverImageUrl)
                            .frame(width: geometry.size.width, height: Layout.cover).clipped()
                    }.frame(height: Layout.cover)
                        .clipShape(RoundedRectangle(cornerRadius: UFitRadius.card)).accessibilityHidden(true)
                    if let author = entry.outfit.author {
                        Text(Copy.author(author.name)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    }
                    HStack(alignment: .top, spacing: UFitSpace.md) {
                        Text(entry.outfit.title).font(UFitTypography.title2).multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: .zero)
                        UFitIcon(systemName: Icon.next).font(UFitTypography.callout).accessibilityHidden(true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.ufitButtonStyle(.text).accessibilityLabel(Copy.open(entry.outfit.title))
                .accessibilityValue(entry.outfit.author.map { Copy.author($0.name) } ?? String())
            VStack(alignment: .leading, spacing: UFitSpace.sm) {
                Text(Copy.pieces).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                ForEach(entry.pieces) { piece in
                    VStack(alignment: .leading, spacing: UFitSpace.xxs) {
                        Text(piece.name).font(UFitTypography.subheadline)
                        if piece.productStatus != .active {
                            Text(piece.productStatus == .archived ? Copy.archived : Copy.draft)
                                .font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        }
                    }
                }
            }
        }
    }
}
