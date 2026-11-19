import SwiftUI

struct UFitWorkspacesContent: View {
    let spaces: [UFitWorkspaceReference]
    let hasLoaded: Bool
    let isLoading: Bool
    let busyIDs: Set<String>
    let message: String?
    let canAdminister: Bool
    let onRefresh: () -> Void
    let onOpen: (UFitWorkspaceReference) -> Void
    let onApplications: () -> Void
    let onPayments: () -> Void
    let onAdminApplications: () -> Void
    let onCatalog: (UFitWorkspaceReference) -> Void
    let onCommercePolicy: (UFitWorkspaceReference) -> Void
    let onOrders: (UFitWorkspaceReference) -> Void
    let onReturns: (UFitWorkspaceReference) -> Void
    let onAdminReturns: () -> Void
    let onAdminProducts: () -> Void
    let onOutfits: (UFitWorkspaceReference) -> Void
    let onAdminOutfits: () -> Void
    let onPublicProfile: (UFitWorkspaceReference) -> Void
    let onDashboard: (UFitWorkspaceReference) -> Void
    private enum Copy {
        static let title = String(localized: "Mes espaces")
        static let refresh = String(localized: "Actualiser")
        static let loading = String(localized: "Chargement des espaces")
        static let empty = String(localized: "Votre univers commence ici.")
        static let apply = String(localized: "Mes candidatures")
        static let payments = String(localized: "Paiements et versements")
        static let admin = String(localized: "Candidatures à examiner")
        static let dashboard = String(localized: "Tableau de bord")
        static let profile = String(localized: "Modifier le profil")
        static let publicProfile = String(localized: "Voir le profil public")
        static let catalog = String(localized: "Catalogue de produits")
        static let commercePolicy = String(localized: "Conditions de vente")
        static let orders = String(localized: "Commandes")
        static let returns = String(localized: "Retours à traiter")
        static let adminReturns = String(localized: "Retours et arbitrages")
        static let outfits = String(localized: "Mes tenues")
        static let adminOutfits = String(localized: "Tenues à examiner")
        static let adminProducts = String(localized: "Produits à examiner")
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs
        static let touch: CGFloat = UFitControlSize.touch; static let bottom: CGFloat = 110; static let title: CGFloat = UFitTypography.Size.editorial; static let radius: CGFloat = UFitRadius.card
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let chevron = "chevron.right" }
    var body: some View {
        VStack(spacing: .zero) {
            HStack {
                Text(Copy.title).ufitFont(size: Layout.title, design: .serif)
                Spacer()
                if isLoading { UFitLoading().frame(width: Layout.touch, height: Layout.touch) }
                else { UFitButton(action: onRefresh) { UFitIcon(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }.padding(.horizontal, Layout.page).padding(.top, Layout.gap)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if let message { Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).accessibilityAddTraits(.updatesFrequently) }
                    if !hasLoaded && isLoading { Text(Copy.loading).foregroundStyle(Color.ufitSecondaryText) }
                    if hasLoaded {
                        if spaces.isEmpty && message == nil && !isLoading { Text(Copy.empty).font(UFitTypography.title2).padding(.vertical, Layout.page) }
                        ForEach(spaces) { space in
                            VStack(alignment: .leading, spacing: Layout.gap) {
                                HStack(alignment: .top, spacing: Layout.gap) {
                                    UFitIcon(systemName: space.systemImage).font(UFitTypography.title2).frame(width: Layout.touch, height: Layout.touch)
                                    VStack(alignment: .leading, spacing: Layout.small) {
                                        Text(space.kindLabel).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                        Text(space.name).font(UFitTypography.title2.weight(.medium))
                                        HStack { Text(space.status.label); if let role = space.roleLabel { Text(role) } }.font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                                    }
                                }
                                UFitButton(action: { onDashboard(space) }) {
                                    HStack { Text(Copy.dashboard); Spacer(); UFitIcon(systemName: Icon.chevron) }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                                }.disabled(space.status == .suspended)
                                UFitButton(action: { onOpen(space) }) {
                                    HStack { Text(Copy.profile); Spacer(); if busyIDs.contains(space.id) { UFitLoading() } else { UFitIcon(systemName: Icon.chevron) } }
                                        .frame(minHeight: Layout.touch).contentShape(Rectangle())
                                }.disabled(busyIDs.contains(space.id))
                                if space.status == .active {
                                    UFitButton(action: { onPublicProfile(space) }) {
                                        HStack { Text(Copy.publicProfile); Spacer(); UFitIcon(systemName: Icon.chevron) }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                                    }
                                }
                                UFitButton(action: { onOutfits(space) }) {
                                    HStack { Text(Copy.outfits); Spacer(); UFitIcon(systemName: Icon.chevron) }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                                }.disabled(space.status != .active && space.status != .paused)
                                if !space.isCreator {
                                    UFitButton(action: { onCatalog(space) }) {
                                        HStack { Text(Copy.catalog); Spacer(); UFitIcon(systemName: Icon.chevron) }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                                    }.disabled(space.status == .suspended)
                                    UFitButton(action: { onOrders(space) }) {
                                        HStack { Text(Copy.orders); Spacer(); UFitIcon(systemName: Icon.chevron) }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                                    }.disabled(space.status != .active && space.status != .paused)
                                    UFitButton(action: { onReturns(space) }) {
                                        HStack { Text(Copy.returns); Spacer(); UFitIcon(systemName: Icon.chevron) }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                                    }.disabled(space.status != .active && space.status != .paused)
                                    UFitButton(action: { onCommercePolicy(space) }) {
                                        HStack { Text(Copy.commercePolicy); Spacer(); UFitIcon(systemName: Icon.chevron) }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                                    }.disabled(space.status != .active && space.status != .paused)
                                }
                            }.padding(Layout.gap).frame(maxWidth: .infinity, alignment: .leading)
                                .overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder) }
                        }
                        VStack(alignment: .leading, spacing: Layout.small) {
                            if spaces.contains(where: { $0.status == .active }) { UFitButton(Copy.payments, action: onPayments).frame(minHeight: Layout.touch) }
                            UFitButton(Copy.apply, action: onApplications).frame(minHeight: Layout.touch)
                        }
                    }
                    if canAdminister {
                        Divider()
                        VStack(alignment: .leading, spacing: Layout.small) {
                            UFitButton(Copy.admin, action: onAdminApplications).frame(minHeight: Layout.touch)
                            UFitButton(Copy.adminProducts, action: onAdminProducts).frame(minHeight: Layout.touch)
                            UFitButton(Copy.adminOutfits, action: onAdminOutfits).frame(minHeight: Layout.touch)
                            UFitButton(Copy.adminReturns, action: onAdminReturns).frame(minHeight: Layout.touch)
                        }
                    }
                }.padding(Layout.page).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}
