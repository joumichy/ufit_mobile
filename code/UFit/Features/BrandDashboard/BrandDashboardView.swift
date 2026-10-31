import SwiftUI

struct BrandDashboardView: View {
    let store: MarketplaceStore
    let onBack: () -> Void

    var body: some View {
        BrandDashboardContentView(
            brandName: brandName,
            subtitle: subtitle,
            workspaceMessage: workspaceMessage,
            summary: summary,
            orders: store.brandOrders,
            onBack: onBack
        )
        .task { await store.loadBrandWorkspace() }
    }

    private var summary: BrandDashboardSummary {
        guard let metrics = store.brandDashboard?.performance else {
            return BrandDashboardSummary(pendingOrders: 24, revenue: "8,942€", activeProducts: "24", lowStock: "3")
        }
        return BrandDashboardSummary(
            pendingOrders: metrics.orders.paid + metrics.orders.preparing,
            revenue: UFitMoney.format(metrics.sales.grossAmount, currency: metrics.sales.currency),
            activeProducts: "\(metrics.products.active)",
            lowStock: "\(metrics.stock.lowStockVariants)"
        )
    }

    private var brandName: String {
        store.brandDashboard?.profile.brandName ?? "Atelier Minimal"
    }

    private var subtitle: String {
        store.brandDashboard.map { "\($0.profile.memberRole.capitalized) workspace" } ?? "Independent Fashion Brand"
    }

    private var workspaceMessage: String? {
        if !store.isAuthenticated {
            return "Connect a brand session to load live products and orders."
        }
        if store.brandProfileID == nil {
            return "Set UFIT_BRAND_PROFILE_ID to load this brand workspace."
        }
        return nil
    }
}

#Preview {
    BrandDashboardView(store: MarketplaceStore.live(), onBack: {})
}
