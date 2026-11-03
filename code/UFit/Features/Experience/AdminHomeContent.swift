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
    var onEditorial: (() -> Void)? = nil
    var onRefundRecoveries: (() -> Void)? = nil
    var refundRecoveryCount: Int? = nil
    var onCommissionLedger: (() -> Void)? = nil
    var onOrders: (() -> Void)? = nil
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
                        UFitActionButton(title: Copy.retry, kind: .secondary, action: onRefresh)
                    }
                    if let onRefundRecoveries, let refundRecoveryCount, refundRecoveryCount > .zero {
                        UFitExperienceActionRow(title: UFitRefundRecoveryCopy.action, count: refundRecoveryCount, systemImage: UFitRefundRecoveryCopy.icon, action: onRefundRecoveries)
                        Divider()
                    }
                    if let activity {
                        if activity.applications > .zero {
                            UFitEditorialHeading(title: AdminDesignCopy.selection, editorial: false)
                            UFitExperienceActionRow(title: Copy.applications, count: activity.applications, systemImage: Icon.applications, action: onApplications)
                        } else if refundRecoveryCount == nil || refundRecoveryCount == .zero { UFitEmptyState(title: AdminDesignCopy.empty, symbol: Icon.complete) }
                    }
                    UFitEditorialHeading(title: AdminDesignCopy.operations, editorial: false)
                    if let onOrders {
                        UFitExperienceActionRow(title: UFitAdminOrdersCopy.title, systemImage: UFitAdminOrdersCopy.icon, action: onOrders)
                        Divider()
                    }
                    if let onRefundRecoveries, refundRecoveryCount == nil || refundRecoveryCount == .zero {
                        UFitExperienceActionRow(title: UFitRefundRecoveryCopy.action, systemImage: UFitRefundRecoveryCopy.icon, action: onRefundRecoveries)
                        Divider()
                    }
                    if let onEditorial {
                        UFitExperienceActionRow(title: UFitEditorialAdminCopy.title, systemImage: UFitEditorialAdminCopy.icon, action: onEditorial)
                        Divider()
                    }
                    UFitExperienceActionRow(title: Copy.products, systemImage: Icon.products, action: onProducts)
                    Divider()
                    UFitExperienceActionRow(title: Copy.outfits, systemImage: Icon.outfits, action: onOutfits)
                    Divider()
                    UFitExperienceActionRow(title: Copy.returns, systemImage: Icon.returns, action: onReturns)
                    Divider()
                    if let onCommissionLedger {
                        UFitExperienceActionRow(title: UFitCommissionLedgerCopy.title, systemImage: UFitCommissionLedgerCopy.icon, action: onCommissionLedger)
                        Divider()
                    }
                    UFitExperienceActionRow(title: UFitCommissionAdminCopy.rules, systemImage: CommissionIcon.rates, action: onCommissions)
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
    static let selection = String(localized: "Candidatures à examiner")
    static let empty = String(localized: "Aucune candidature en attente")
    static let operations = String(localized: "Opérations")
}
