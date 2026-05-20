import SwiftUI

struct BrandDashboardView: View {
    let store: MarketplaceStore
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(title: "Brand Dashboard", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    BrandDashboardHeader(brandName: brandName, subtitle: subtitle)
                    if let message = workspaceMessage {
                        WorkspaceNotice(message: message)
                    }
                    BrandMetricsSection(metrics: store.brandDashboard?.performance)
                    RevenueSummaryCard(metrics: store.brandDashboard?.performance)
                    RecentOrdersSection(orders: store.brandOrders)
                }
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 104)
            }
            .scrollIndicators(.hidden)
            .background(Color.white)
        }
        .background(Color.white)
        .task {
            await store.loadBrandWorkspace()
        }
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

private struct BrandDashboardHeader: View {
    let brandName: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(brandName)
                .font(.system(size: 28, weight: .regular))
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Color.ufitMuted)
        }
    }
}

private struct BrandMetricsSection: View {
    let metrics: UFitBrandPerformanceDTO?

    var body: some View {
        HStack(spacing: 14) {
            MetricCard(icon: "shippingbox", value: "\(pendingOrders)", label: "Pending Orders")
            MetricCard(icon: "eurosign.circle", value: revenue, label: "Revenue")
        }
    }

    private var pendingOrders: Int {
        guard let metrics else { return 24 }
        return metrics.orders.paid + metrics.orders.preparing
    }

    private var revenue: String {
        guard let metrics else { return "8,942€" }
        return UFitMoney.format(metrics.sales.grossAmount, currency: metrics.sales.currency)
    }
}

private struct RevenueSummaryCard: View {
    let metrics: UFitBrandPerformanceDTO?

    var body: some View {
        VStack(spacing: 13) {
            DashboardRow(label: "Total Revenue", value: totalRevenue, valueSize: 22)
            DashboardRow(label: "Products active", value: activeProducts, muted: true)
            Divider()
            DashboardRow(label: "Low stock variants", value: lowStock, valueSize: 22)
        }
        .padding(18)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var totalRevenue: String {
        guard let metrics else { return "8,942€" }
        return UFitMoney.format(metrics.sales.grossAmount, currency: metrics.sales.currency)
    }

    private var activeProducts: String {
        guard let metrics else { return "24" }
        return "\(metrics.products.active)"
    }

    private var lowStock: String {
        guard let metrics else { return "3" }
        return "\(metrics.stock.lowStockVariants)"
    }
}

private struct RecentOrdersSection: View {
    let orders: [BrandOrder]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Orders")
                    .font(.system(size: 20, weight: .medium))
                Spacer()
                Button("View all") {}
                    .font(.system(size: 14))
                    .foregroundStyle(Color.ufitMuted)
            }

            ForEach(orders) { order in
                OrderCard(order: order)
            }
        }
    }
}

private struct WorkspaceNotice: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(Color.ufitMuted)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    BrandDashboardView(store: MarketplaceStore.live(), onBack: {})
}
