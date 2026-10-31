import SwiftUI

struct BrandDashboardSummary {
    let pendingOrders: Int
    let revenue: String
    let activeProducts: String
    let lowStock: String
}

struct BrandDashboardContentView: View {
    let brandName: String
    let subtitle: String
    let workspaceMessage: String?
    let summary: BrandDashboardSummary
    let orders: [BrandOrder]
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(title: "Brand Dashboard", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    BrandDashboardHeader(brandName: brandName, subtitle: subtitle)
                    if let message = workspaceMessage {
                        BrandWorkspaceNotice(message: message)
                    }
                    BrandMetricsSection(summary: summary)
                    RevenueSummaryCard(summary: summary)
                    RecentOrdersSection(orders: orders)
                }
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 104)
            }
            .scrollIndicators(.hidden)
            .background(Color.white)
        }
        .background(Color.white)
    }
}

struct BrandDashboardHeader: View {
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

struct BrandMetricsSection: View {
    let summary: BrandDashboardSummary

    var body: some View {
        HStack(spacing: 14) {
            MetricCard(icon: "shippingbox", value: "\(summary.pendingOrders)", label: "Pending Orders")
            MetricCard(icon: "eurosign.circle", value: summary.revenue, label: "Revenue")
        }
    }

}

struct RevenueSummaryCard: View {
    let summary: BrandDashboardSummary

    var body: some View {
        VStack(spacing: 13) {
            DashboardRow(label: "Total Revenue", value: summary.revenue, valueSize: 22)
            DashboardRow(label: "Products active", value: summary.activeProducts, muted: true)
            Divider()
            DashboardRow(label: "Low stock variants", value: summary.lowStock, valueSize: 22)
        }
        .padding(18)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

}

struct RecentOrdersSection: View {
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

struct BrandWorkspaceNotice: View {
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
