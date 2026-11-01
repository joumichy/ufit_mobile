import SwiftUI

struct CreateWorkspaceContentView: View {
    let creatorSubtitle: String
    let creatorMetric: String
    let brandSubtitle: String
    let brandMetric: String
    let noticeText: String
    let onCreatorTap: () -> Void
    let onBrandTap: () -> Void

    var body: some View {
        VStack(spacing: .zero) {
            RootScreenHeader(title: "Create", subtitle: "Compose looks and manage partner workspaces.")

            ScrollView {
                VStack(spacing: UFitSpace.md) {
                    WorkspaceEntryCard(
                        systemImage: "sparkles",
                        title: "Creator studio",
                        subtitle: creatorSubtitle,
                        primaryMetric: creatorMetric,
                        actionTitle: "Open profile",
                        action: onCreatorTap
                    )

                    WorkspaceEntryCard(
                        systemImage: "shippingbox",
                        title: "Brand workspace",
                        subtitle: brandSubtitle,
                        primaryMetric: brandMetric,
                        actionTitle: "Open dashboard",
                        action: onBrandTap
                    )

                    WorkspaceNotice(text: noticeText)
                }
                .padding(.horizontal, UFitSpace.xl)
                .padding(.bottom, UFitSpace.xl)
            }
            .scrollIndicators(.hidden)
            .background(Color.ufitCanvas)
        }
        .background(Color.ufitCanvas)
    }
}
