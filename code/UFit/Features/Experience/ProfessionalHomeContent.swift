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
            UFitExperienceHeader(title: Copy.title, name: workspace.name, kind: .creator, onChooseExperience: onChooseExperience, onRefresh: message == nil ? onRefresh : nil, isLoading: isLoading)
            ScrollView {
                VStack(alignment: .leading, spacing: ProfessionalLayout.page) {
                    if workspace.status != .active { UFitNotice(message: workspace.status.label) }
                    if let document {
                        let work = document.activity.filter { $0.id == .draft && $0.value > .zero }
                            .sorted { ProfessionalQueueOrder.priority($0.id) < ProfessionalQueueOrder.priority($1.id) }
                        if !work.isEmpty {
                            UFitEditorialHeading(title: StudioCopy.resume, editorial: false)
                            VStack(spacing: .zero) {
                                ForEach(work) { row in
                                    UFitExperienceActionRow(title: row.label, count: row.value) { onOutfits(outfitFilter(row.id)) }
                                    Divider()
                                }
                            }
                        }
                        UFitActionButton(title: Copy.create, kind: work.isEmpty ? .primary : .secondary,
                            disabled: workspace.status == .suspended, action: onCreate)
                        if let scheduled = document.activity.first(where: { $0.id == .scheduled }), scheduled.value > .zero {
                            UFitExperienceActionRow(title: scheduled.label, count: scheduled.value) { onOutfits(.scheduled) }
                        }
                        let collection = document.activity.filter { $0.id == .outfits || $0.id == .published }
                        if collection.contains(where: { $0.value > .zero }) {
                            UFitEditorialHeading(title: Copy.work, editorial: false)
                            VStack(spacing: .zero) {
                                ForEach(collection) { row in
                                    UFitExperienceActionRow(title: row.label, count: row.value) { onOutfits(row.id == .published ? .published : nil) }
                                    Divider()
                                }
                            }
                        }
                        if let grade = document.grade { Text(grade).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText) }
                        if workspace.status == .active { UFitExperienceActionRow(title: Copy.preview, systemImage: ProfessionalIcon.publicProfile, action: onPublicProfile) }
                        if isLoading { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                    } else if isLoading || message == nil { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                    else { UFitActionButton(title: Copy.create, kind: .secondary, disabled: workspace.status == .suspended, action: onCreate) }
                    if let message { UFitNotice(message: message, kind: .error); UFitActionButton(title: Copy.retry, kind: .secondary, action: onRefresh) }
                }.padding(.horizontal, ProfessionalLayout.page).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func outfitFilter(_ key: UFitWorkspaceActivityFigure.Key) -> UFitOutfitStatus? {
        switch key { case .draft: .draft; case .scheduled: .scheduled; default: nil }
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
            UFitExperienceHeader(title: Copy.title, name: workspace.name, kind: .brand, onChooseExperience: onChooseExperience, onRefresh: message == nil ? onRefresh : nil, isLoading: isLoading)
            ScrollView {
                VStack(alignment: .leading, spacing: ProfessionalLayout.page) {
                    if workspace.status != .active { UFitNotice(message: workspace.status.label) }
                    if let document {
                        let fulfilment = document.activity.filter { $0.id == .paid || $0.id == .preparing || $0.id == .shipped }
                        let hasOrders = fulfilment.contains { $0.value > .zero }
                        let drafts = document.activity.filter { $0.id == .draft && $0.value > .zero }
                        if hasOrders {
                            VStack(alignment: .leading, spacing: UFitSpace.lg) {
                                UFitEditorialHeading(title: BrandCopy.fulfilment, editorial: false)
                                ProfessionalFigures(rows: fulfilment)
                                UFitActionButton(title: BrandCopy.manageOrders, action: onOrders)
                            }.padding(UFitSpace.lg).background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card))
                        }
                        UFitEditorialHeading(title: Copy.catalog, editorial: false)
                        if let products = document.activity.first(where: { $0.id == .products }), products.value == .zero && drafts.isEmpty {
                            UFitActionButton(title: Copy.add, kind: hasOrders ? .secondary : .primary,
                                disabled: workspace.status == .suspended, action: onAddProduct)
                        } else {
                            UFitActionButton(title: BrandCopy.openCatalog, kind: hasOrders ? .secondary : .primary) { onCatalog(nil) }
                            ForEach(drafts) { row in
                                UFitExperienceActionRow(title: row.label, count: row.value) { onCatalog(.draft) }
                                Divider()
                            }
                            if let stock = document.activity.first(where: { $0.id == .lowStock }), stock.value > .zero {
                                HStack { Text(stock.label); Spacer(); Text(stock.value, format: .number) }.font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                            }
                            UFitActionButton(title: Copy.add, kind: .secondary, disabled: workspace.status == .suspended, action: onAddProduct)
                        }
                        UFitEditorialHeading(title: BrandCopy.service, editorial: false)
                        if !hasOrders { UFitExperienceActionRow(title: Copy.orders, systemImage: ProfessionalIcon.orders, action: onOrders) }
                        UFitExperienceActionRow(title: Copy.returns, subtitle: BrandCopy.returns, systemImage: ProfessionalIcon.returns, action: onReturns)
                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                            UFitEditorialHeading(title: Copy.sales, editorial: false)
                            if document.sales.isEmpty { Text(Copy.noSales).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                            else { Text(Copy.net).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText); ForEach(document.sales) { row in Text(row.net).font(UFitTypography.title2).monospacedDigit() } }
                            UFitExperienceActionRow(title: Copy.salesDetail, action: onSales)
                        }
                        if isLoading { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                    } else if isLoading || message == nil { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                    else { UFitActionButton(title: Copy.add, kind: .secondary, disabled: workspace.status == .suspended, action: onAddProduct) }
                    if let message { UFitNotice(message: message, kind: .error); UFitActionButton(title: Copy.retry, kind: .secondary, action: onRefresh) }
                }.padding(.horizontal, ProfessionalLayout.page).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}

private struct ProfessionalFigures: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let rows: [UFitWorkspaceActivityFigure]
    private enum Layout { static let spacing: CGFloat = UFitSpace.md; static let font: CGFloat = UFitTypography.Size.title; static let single = [GridItem(.flexible(), alignment: .leading)] }
    var body: some View {
        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? Layout.single : rows.map { _ in GridItem(.flexible(), alignment: .leading) }, alignment: .leading, spacing: Layout.spacing) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: ProfessionalLayout.small) {
                    Text(row.value, format: .number).ufitFont(size: Layout.font, weight: .regular, design: .serif).monospacedDigit()
                    Text(row.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
            }
        }
    }
}
private enum ProfessionalLayout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let bottom: CGFloat = 110; static let touch: CGFloat = UFitControlSize.touch }
private enum ProfessionalIcon { static let publicProfile = "person.crop.circle"; static let orders = "shippingbox"; static let returns = "arrow.uturn.backward" }

private enum StudioCopy {
    static let resume = String(localized: "À reprendre")
}
private enum BrandCopy {
    static let fulfilment = String(localized: "Commandes à suivre")
    static let service = String(localized: "Service")
    static let openCatalog = String(localized: "Ouvrir le catalogue")
    static let manageOrders = String(localized: "Gérer les commandes")
    static let returns = String(localized: "Demandes et suivi des remboursements")
}

private enum ProfessionalQueueOrder {
    static func priority(_ key: UFitWorkspaceActivityFigure.Key) -> Int { switch key { case .draft: 0; case .scheduled: 1; default: 2 } }
}
