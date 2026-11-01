import SwiftUI

struct UFitCreatorStudioContent: View {
    let workspace: UFitWorkspaceReference
    let document: UFitWorkspaceDashboardPresentation?
    let isLoading: Bool
    let message: String?
    let onRefresh: () -> Void
    let onCreate: () -> Void
    let onOutfits: (UFitOutfitStatus?) -> Void
    let onPublicProfile: () -> Void
    let onChooseExperience: () -> Void
    private enum Copy {
        static let title = String(localized: "Studio")
        static let create = String(localized: "Créer une tenue")
        static let work = String(localized: "Vos tenues")
        static let preview = String(localized: "Voir mon profil public")
        static let retry = String(localized: "Réessayer"); static let loading = String(localized: "Chargement du studio")
    }
    var body: some View {
        VStack(spacing: .zero) {
            UFitExperienceHeader(title: Copy.title, name: workspace.name, kind: .creator, onChooseExperience: onChooseExperience, onRefresh: onRefresh, isLoading: isLoading)
            ScrollView {
                VStack(alignment: .leading, spacing: ProfessionalLayout.page) {
                    if workspace.status != .active { Text(workspace.status.label).font(.callout).foregroundStyle(Color.ufitMuted) }
                    Button(action: onCreate) { Text(Copy.create).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).disabled(workspace.status == .suspended)
                    if let document {
                        HStack {
                            if let grade = document.grade { Text(grade).font(.subheadline.weight(.medium)) }
                            Spacer()
                        }
                        ProfessionalFigures(rows: document.activity.filter { $0.id == .outfits || $0.id == .published })
                        VStack(alignment: .leading, spacing: .zero) {
                            Text(Copy.work).font(.title2.weight(.medium)).padding(.bottom, ProfessionalLayout.small)
                            ForEach(document.activity.filter { $0.id == .draft || $0.id == .review || $0.id == .rejected }) { row in
                                UFitExperienceActionRow(title: row.label, count: row.value) { onOutfits(outfitFilter(row.id)) }
                                Divider()
                            }
                        }
                        if workspace.status == .active {
                            UFitExperienceActionRow(title: Copy.preview, systemImage: ProfessionalIcon.publicProfile, action: onPublicProfile)
                        }
                    } else if isLoading || message == nil { ProgressView(Copy.loading).frame(maxWidth: .infinity) }
                    if let message {
                        Text(message).font(.callout).foregroundStyle(Color.ufitMuted)
                        Button(Copy.retry, action: onRefresh).frame(minHeight: ProfessionalLayout.touch)
                    }
                }.padding(.horizontal, ProfessionalLayout.page).padding(.bottom, ProfessionalLayout.bottom).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
    private func outfitFilter(_ key: UFitWorkspaceActivityFigure.Key) -> UFitOutfitStatus? {
        switch key { case .draft: .draft; case .review: .underReview; case .rejected: .rejected; default: nil }
    }
}

struct UFitBrandActivityContent: View {
    let workspace: UFitWorkspaceReference
    let document: UFitWorkspaceDashboardPresentation?
    let isLoading: Bool
    let message: String?
    let onRefresh: () -> Void
    let onAddProduct: () -> Void
    let onCatalog: (UFitCatalogStatus?) -> Void
    let onOrders: () -> Void
    let onReturns: () -> Void
    let onSales: () -> Void
    let onChooseExperience: () -> Void
    private enum Copy {
        static let title = String(localized: "Activité")
        static let add = String(localized: "Ajouter un article")
        static let orders = String(localized: "Commandes"); static let returns = String(localized: "Retours")
        static let catalog = String(localized: "Catalogue"); static let sales = String(localized: "Ventes")
        static let net = String(localized: "Net après remboursements"); static let noSales = String(localized: "Aucun encaissement pour le moment.")
        static let salesDetail = String(localized: "Voir les encaissements")
        static let retry = String(localized: "Réessayer"); static let loading = String(localized: "Chargement de l’activité")
    }
    var body: some View {
        VStack(spacing: .zero) {
            UFitExperienceHeader(title: Copy.title, name: workspace.name, kind: .brand, onChooseExperience: onChooseExperience, onRefresh: onRefresh, isLoading: isLoading)
            ScrollView {
                VStack(alignment: .leading, spacing: ProfessionalLayout.page) {
                    if workspace.status != .active { Text(workspace.status.label).font(.callout).foregroundStyle(Color.ufitMuted) }
                    Button(action: onAddProduct) { Text(Copy.add).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).disabled(workspace.status == .suspended)
                    if let document {
                        VStack(alignment: .leading, spacing: ProfessionalLayout.gap) {
                            UFitExperienceActionRow(title: Copy.orders, systemImage: ProfessionalIcon.orders, action: onOrders)
                            ProfessionalFigures(rows: document.activity.filter { $0.id == .paid || $0.id == .preparing || $0.id == .shipped })
                            UFitExperienceActionRow(title: Copy.returns, systemImage: ProfessionalIcon.returns, action: onReturns)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: .zero) {
                            Text(Copy.catalog).font(.title2.weight(.medium)).padding(.bottom, ProfessionalLayout.small)
                            ForEach(document.activity.filter { $0.id == .review || $0.id == .rejected }) { row in
                                UFitExperienceActionRow(title: row.label, count: row.value) { onCatalog(row.id == .review ? .underReview : .rejected) }
                                Divider()
                            }
                            if let stock = document.activity.first(where: { $0.id == .lowStock }) {
                                HStack { Text(stock.label); Spacer(); Text(stock.value, format: .number).monospacedDigit() }.font(.callout).foregroundStyle(Color.ufitMuted).padding(.vertical, ProfessionalLayout.gap)
                            }
                        }
                        VStack(alignment: .leading, spacing: ProfessionalLayout.small) {
                            Text(Copy.sales).font(.title2.weight(.medium))
                            if document.sales.isEmpty { Text(Copy.noSales).font(.callout).foregroundStyle(Color.ufitMuted) }
                            else {
                                Text(Copy.net).font(.caption).foregroundStyle(Color.ufitMuted)
                                ForEach(document.sales) { row in Text(row.net).font(.title2).monospacedDigit() }
                            }
                            UFitExperienceActionRow(title: Copy.salesDetail, action: onSales)
                        }
                    } else if isLoading || message == nil { ProgressView(Copy.loading).frame(maxWidth: .infinity) }
                    if let message {
                        Text(message).font(.callout).foregroundStyle(Color.ufitMuted)
                        Button(Copy.retry, action: onRefresh).frame(minHeight: ProfessionalLayout.touch)
                    }
                }.padding(.horizontal, ProfessionalLayout.page).padding(.bottom, ProfessionalLayout.bottom).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
}
private struct ProfessionalFigures: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let rows: [UFitWorkspaceActivityFigure]
    private enum Layout { static let spacing: CGFloat = 16; static let font: CGFloat = 28; static let single = [GridItem(.flexible(), alignment: .leading)] }
    var body: some View {
        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? Layout.single : rows.map { _ in GridItem(.flexible(), alignment: .leading) }, alignment: .leading, spacing: Layout.spacing) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: ProfessionalLayout.small) {
                    Text(row.value, format: .number).font(.system(size: Layout.font, weight: .regular, design: .serif)).monospacedDigit()
                    Text(row.label).font(.caption).foregroundStyle(Color.ufitMuted).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
            }
        }
    }
}
private enum ProfessionalLayout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let bottom: CGFloat = 110; static let touch: CGFloat = 44 }
private enum ProfessionalIcon { static let publicProfile = "person.crop.circle"; static let orders = "shippingbox"; static let returns = "arrow.uturn.backward" }
