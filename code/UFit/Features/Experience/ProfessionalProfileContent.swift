import SwiftUI

struct UFitProfessionalProfileContent: View {
    let workspace: UFitWorkspaceReference
    var isOpening = false
    var message: String?
    let onAction: (UFitProfessionalProfileAction) -> Void
    let onChooseExperience: () -> Void
    private enum Copy {
        static let creatorTitle = String(localized: "Mon profil créateur"); static let brandTitle = String(localized: "Ma marque")
        static let edit = String(localized: "Modifier le profil"); static let preview = String(localized: "Voir la page publique")
        static let sales = String(localized: "Ventes et encaissements"); static let policy = String(localized: "Conditions de vente")
        static let creatorPayments = String(localized: "Compte de versement"); static let brandPayments = String(localized: "Paiements et versements")
        static let account = String(localized: "Mon compte personnel")
    }
    private enum Icon {
        static let edit = "pencil"; static let preview = "arrow.up.right.square"; static let sales = "chart.line.uptrend.xyaxis"
        static let policy = "doc.text"; static let payments = "creditcard"; static let account = "person.crop.circle"
    }
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let bottom: CGFloat = 110 }
    var body: some View {
        VStack(spacing: .zero) {
            UFitExperienceHeader(title: workspace.isCreator ? Copy.creatorTitle : Copy.brandTitle, name: workspace.name,
                kind: workspace.isCreator ? .creator : .brand, onChooseExperience: onChooseExperience)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.gap) {
                    HStack {
                        Text(workspace.status.label)
                        if let role = workspace.roleLabel { Text(role) }
                    }.font(.subheadline).foregroundStyle(Color.ufitMuted)
                    if let message { Text(message).font(.callout).foregroundStyle(Color.ufitMuted) }
                    VStack(spacing: .zero) {
                        UFitExperienceActionRow(title: Copy.edit, systemImage: Icon.edit, isBusy: isOpening) { onAction(.edit) }
                        Divider()
                        if workspace.status == .active {
                            UFitExperienceActionRow(title: Copy.preview, systemImage: Icon.preview) { onAction(.publicProfile) }
                            Divider()
                        }
                        if !workspace.isCreator {
                            UFitExperienceActionRow(title: Copy.policy, systemImage: Icon.policy) { onAction(.commercePolicy) }
                            Divider()
                            UFitExperienceActionRow(title: Copy.sales, systemImage: Icon.sales) { onAction(.sales) }
                            Divider()
                        }
                        if workspace.status == .active {
                            UFitExperienceActionRow(title: workspace.isCreator ? Copy.creatorPayments : Copy.brandPayments, systemImage: Icon.payments) { onAction(.payments) }
                        }
                    }
                    Divider().padding(.vertical, Layout.gap)
                    UFitExperienceActionRow(title: Copy.account, systemImage: Icon.account) { onAction(.personalAccount) }
                }.padding(.horizontal, Layout.page).padding(.bottom, Layout.bottom)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
}
