import SwiftUI

struct CreatorProfileView: View {
    let store: MarketplaceStore
    let onBack: () -> Void

    var body: some View {
        CreatorProfileContentView(
            displayName: displayName,
            creatorSlug: creatorSlug,
            creatorStats: creatorStats,
            creatorGrade: creatorGrade,
            workspaceMessage: workspaceMessage,
            onBack: onBack
        )
        .task { await store.loadCreatorWorkspace() }
    }

    private var displayName: String {
        store.creatorDashboard?.profile.displayName ?? "Sofia Laurent"
    }

    private var creatorSlug: String {
        store.creatorDashboard.map { "@\($0.profile.slug)" } ?? "@sofialaurent"
    }

    private var creatorGrade: CreatorGradeSnapshot {
        guard let grade = store.creatorDashboard?.profile.grade else {
            return CreatorGradeSnapshot(label: "Elite", commissionRate: "12%")
        }
        return CreatorGradeSnapshot(label: grade.label, commissionRate: "\(grade.commissionBps / 100)%")
    }

    private var creatorStats: [CreatorStatSnapshot] {
        guard let performance = store.creatorDashboard?.performance else {
            return [
                CreatorStatSnapshot(icon: "person.2", value: "12.4k", label: "Followers"),
                CreatorStatSnapshot(icon: "shippingbox", value: "87", label: "Outfits"),
                CreatorStatSnapshot(icon: "medal", value: "Elite", label: "Grade")
            ]
        }

        return [
            CreatorStatSnapshot(icon: "shippingbox", value: "\(performance.outfits.total)", label: "Outfits"),
            CreatorStatSnapshot(icon: "bag", value: "\(performance.sales.paidOrderCount)", label: "Sales"),
            CreatorStatSnapshot(icon: "eurosign.circle", value: UFitMoney.format(performance.commissions.pendingAmount, currency: performance.sales.currency), label: "Pending")
        ]
    }

    private var workspaceMessage: String? {
        store.creatorDashboard == nil && !store.isAuthenticated ? "Connect a creator session to load live performance." : nil
    }

}

#Preview {
    CreatorProfileView(store: MarketplaceStore.live(), onBack: {})
}
