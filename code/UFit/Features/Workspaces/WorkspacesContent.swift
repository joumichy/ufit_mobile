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
    let onAdminProducts: () -> Void
    private enum Copy {
        static let title = String(localized: "Mes espaces")
        static let refresh = String(localized: "Actualiser")
        static let loading = String(localized: "Chargement des espaces")
        static let empty = String(localized: "Votre univers commence ici.")
        static let apply = String(localized: "Mes candidatures")
        static let payments = String(localized: "Paiements et versements")
        static let admin = String(localized: "Candidatures à examiner")
        static let profile = String(localized: "Modifier le profil")
        static let catalog = String(localized: "Catalogue de produits")
        static let adminProducts = String(localized: "Produits à examiner")
    }
    private enum Layout {
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8
        static let touch: CGFloat = 44; static let bottom: CGFloat = 110; static let title: CGFloat = 32; static let radius: CGFloat = 16
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let chevron = "chevron.right" }
    var body: some View {
        VStack(spacing: .zero) {
            HStack {
                Text(Copy.title).font(.system(size: Layout.title, design: .serif))
                Spacer()
                if isLoading { ProgressView().frame(width: Layout.touch, height: Layout.touch) }
                else { Button(action: onRefresh) { Image(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }.padding(.horizontal, Layout.page).padding(.top, Layout.gap)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if let message { Text(message).font(.callout).foregroundStyle(Color.ufitMuted).accessibilityAddTraits(.updatesFrequently) }
                    if !hasLoaded && isLoading { Text(Copy.loading).foregroundStyle(Color.ufitMuted) }
                    if hasLoaded {
                        if spaces.isEmpty { Text(Copy.empty).font(.title2).padding(.vertical, Layout.page) }
                        ForEach(spaces) { space in
                            VStack(alignment: .leading, spacing: Layout.gap) {
                                HStack(alignment: .top, spacing: Layout.gap) {
                                    Image(systemName: space.systemImage).font(.title2).frame(width: Layout.touch, height: Layout.touch)
                                    VStack(alignment: .leading, spacing: Layout.small) {
                                        Text(space.kindLabel).font(.caption).foregroundStyle(Color.ufitMuted)
                                        Text(space.name).font(.title2.weight(.medium))
                                        HStack { Text(space.status.label); if let role = space.roleLabel { Text(role) } }.font(.subheadline).foregroundStyle(Color.ufitMuted)
                                    }
                                }
                                Button(action: { onOpen(space) }) {
                                    HStack { Text(Copy.profile); Spacer(); if busyIDs.contains(space.id) { ProgressView() } else { Image(systemName: Icon.chevron) } }
                                        .frame(minHeight: Layout.touch).contentShape(Rectangle())
                                }.disabled(busyIDs.contains(space.id))
                                if !space.isCreator {
                                    Button(action: { onCatalog(space) }) {
                                        HStack { Text(Copy.catalog); Spacer(); Image(systemName: Icon.chevron) }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                                    }.disabled(space.status == .suspended)
                                }
                            }.padding(Layout.gap).frame(maxWidth: .infinity, alignment: .leading)
                                .overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder) }
                        }
                        VStack(alignment: .leading, spacing: Layout.small) {
                            if spaces.contains(where: { $0.status == .active }) { Button(Copy.payments, action: onPayments).frame(minHeight: Layout.touch) }
                            Button(Copy.apply, action: onApplications).frame(minHeight: Layout.touch)
                        }
                    }
                    if canAdminister {
                        Divider()
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Button(Copy.admin, action: onAdminApplications).frame(minHeight: Layout.touch)
                            Button(Copy.adminProducts, action: onAdminProducts).frame(minHeight: Layout.touch)
                        }
                    }
                }.padding(Layout.page).padding(.bottom, Layout.bottom).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
}
