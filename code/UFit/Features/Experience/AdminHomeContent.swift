import SwiftUI

struct UFitAdminHomeContent: View {
    let activity: UFitAdminActivity?
    let isLoading: Bool
    let message: String?
    let onRefresh: () -> Void
    let onApplications: () -> Void
    let onProducts: () -> Void
    let onOutfits: () -> Void
    let onReturns: () -> Void
    let onCommissions: () -> Void
    let onUsers: () -> Void
    let onGrades: () -> Void
    let onChooseExperience: () -> Void
    private enum Copy {
        static let title = String(localized: "À traiter"); static let context = String(localized: "Administration")
        static let applications = String(localized: "Candidatures"); static let products = String(localized: "Produits"); static let outfits = String(localized: "Tenues")
        static let returns = String(localized: "Retours et arbitrages"); static let loading = String(localized: "Chargement des dossiers")
        static let retry = String(localized: "Réessayer")
    }
    private enum Icon { static let applications = "person.text.rectangle"; static let products = "tag"; static let outfits = "rectangle.stack"; static let returns = "arrow.uturn.backward"; static let complete = "checkmark.circle" }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let bottom: CGFloat = 110; static let touch: CGFloat = UFitControlSize.touch }
    var body: some View {
        VStack(spacing: .zero) {
            UFitExperienceHeader(title: Copy.title, name: Copy.context, kind: .administrator, onChooseExperience: onChooseExperience, onRefresh: message == nil ? onRefresh : nil, isLoading: isLoading)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.gap) {
                    if isLoading { UFitLoading(Copy.loading) }
                    if let message {
                        Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        UFitButton(Copy.retry, action: onRefresh).frame(minHeight: Layout.touch)
                    }
                    if let activity {
                        if activity.applications > .zero || activity.products > .zero || activity.outfits > .zero {
                            UFitEditorialHeading(title: AdminDesignCopy.selection, editorial: false)
                            VStack(spacing: .zero) {
                                if activity.applications > .zero {
                                    UFitExperienceActionRow(title: Copy.applications, count: activity.applications, systemImage: Icon.applications, action: onApplications)
                                    Divider()
                                }
                                if activity.products > .zero {
                                    UFitExperienceActionRow(title: Copy.products, count: activity.products, systemImage: Icon.products, action: onProducts)
                                    Divider()
                                }
                                if activity.outfits > .zero { UFitExperienceActionRow(title: Copy.outfits, count: activity.outfits, systemImage: Icon.outfits, action: onOutfits) }
                            }
                        } else { UFitEmptyState(title: AdminDesignCopy.empty, symbol: Icon.complete) }
                    }
                    UFitEditorialHeading(title: AdminDesignCopy.operations, editorial: false)
                    UFitExperienceActionRow(title: Copy.returns, systemImage: Icon.returns, action: onReturns)
                    Divider()
                    UFitExperienceActionRow(title: UFitCommissionAdminCopy.title, systemImage: CommissionIcon.rates, action: onCommissions)
                    Divider()
                    UFitExperienceActionRow(title: UFitUserAdministrationCopy.title, systemImage: UserIcon.accounts, action: onUsers)
                    Divider()
                    UFitExperienceActionRow(title: UFitCreatorGradeAdminCopy.title, systemImage: GradeIcon.grades, action: onGrades)
                }.padding(.horizontal, Layout.page).padding(.bottom, UFitSpace.xl)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}
private enum CommissionIcon { static let rates = "percent" }
private enum GradeIcon { static let grades = "tag" }
private enum UserIcon { static let accounts = "person.2" }

private enum AdminDesignCopy {
    static let selection = String(localized: "Dossiers à examiner")
    static let empty = String(localized: "Aucun dossier à examiner")
    static let operations = String(localized: "Opérations")
}
