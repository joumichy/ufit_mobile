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
        VStack(spacing: 0) {
            RootScreenHeader(title: "Create", subtitle: "Compose looks and manage partner workspaces.")

            ScrollView {
                VStack(spacing: 14) {
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
                .padding(.horizontal, 24)
                .padding(.bottom, 104)
            }
            .scrollIndicators(.hidden)
            .background(Color.white)
        }
        .background(Color.white)
    }
}
