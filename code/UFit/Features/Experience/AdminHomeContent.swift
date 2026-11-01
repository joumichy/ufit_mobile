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
    let onChooseExperience: () -> Void
    private enum Copy {
        static let title = String(localized: "À traiter"); static let context = String(localized: "Administration")
        static let applications = String(localized: "Candidatures"); static let products = String(localized: "Produits"); static let outfits = String(localized: "Tenues")
        static let returns = String(localized: "Retours et arbitrages"); static let loading = String(localized: "Chargement des dossiers")
        static let retry = String(localized: "Réessayer")
    }
    private enum Icon { static let applications = "person.text.rectangle"; static let products = "tag"; static let outfits = "rectangle.stack"; static let returns = "arrow.uturn.backward" }
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let bottom: CGFloat = 110; static let touch: CGFloat = 44 }
    var body: some View {
        VStack(spacing: .zero) {
            UFitExperienceHeader(title: Copy.title, name: Copy.context, kind: .administrator, onChooseExperience: onChooseExperience, onRefresh: onRefresh, isLoading: isLoading)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.gap) {
                    if isLoading && activity == nil { ProgressView(Copy.loading) }
                    if let message {
                        Text(message).font(.callout).foregroundStyle(Color.ufitMuted)
                        Button(Copy.retry, action: onRefresh).frame(minHeight: Layout.touch)
                    }
                    VStack(spacing: .zero) {
                        UFitExperienceActionRow(title: Copy.applications, count: activity?.applications, systemImage: Icon.applications, action: onApplications)
                        Divider()
                        UFitExperienceActionRow(title: Copy.products, count: activity?.products, systemImage: Icon.products, action: onProducts)
                        Divider()
                        UFitExperienceActionRow(title: Copy.outfits, count: activity?.outfits, systemImage: Icon.outfits, action: onOutfits)
                    }
                    Divider()
                    UFitExperienceActionRow(title: Copy.returns, systemImage: Icon.returns, action: onReturns)
                }.padding(.horizontal, Layout.page).padding(.bottom, Layout.bottom)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
}
