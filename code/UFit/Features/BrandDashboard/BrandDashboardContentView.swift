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
        VStack(spacing: .zero) {
            DetailHeader(title: "Brand Dashboard", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    BrandDashboardHeader(brandName: brandName, subtitle: subtitle)
                    if let message = workspaceMessage {
                        BrandWorkspaceNotice(message: message)
                    }
                    BrandMetricsSection(summary: summary)
                    RevenueSummaryCard(summary: summary)
                    RecentOrdersSection(orders: orders)
                }
                .padding(.horizontal, UFitSpace.xl)
                .padding(.top, 26)
                .padding(.bottom, UFitSpace.xl)
            }
            .scrollIndicators(.hidden)
            .background(Color.ufitCanvas)
        }
        .background(Color.ufitCanvas)
    }
}

struct BrandDashboardHeader: View {
    let brandName: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xxs) {
            Text(brandName)
                .ufitFont(size: UFitTypography.Size.title, weight: .regular)
            Text(subtitle)
                .ufitFont(size: UFitTypography.Size.small)
                .foregroundStyle(Color.ufitSecondaryText)
        }
    }
}

struct BrandMetricsSection: View {
    let summary: BrandDashboardSummary

    var body: some View {
        HStack(spacing: UFitSpace.md) {
            MetricCard(icon: "shippingbox", value: "\(summary.pendingOrders)", label: "Pending Orders")
            MetricCard(icon: "eurosign.circle", value: summary.revenue, label: "Revenue")
        }
    }

}

struct RevenueSummaryCard: View {
    let summary: BrandDashboardSummary

    var body: some View {
        VStack(spacing: UFitSpace.sm) {
            DashboardRow(label: "Total Revenue", value: summary.revenue, valueSize: 22)
            DashboardRow(label: "Products active", value: summary.activeProducts, muted: true)
            Divider()
            DashboardRow(label: "Low stock variants", value: summary.lowStock, valueSize: 22)
        }
        .padding(18)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card, style: .continuous))
    }

}

struct RecentOrdersSection: View {
    let orders: [BrandOrder]

    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            HStack {
                Text("Recent Orders")
                    .ufitFont(size: UFitTypography.Size.section, weight: .medium)
                Spacer()
                UFitButton("View all") {}
                    .ufitFont(size: UFitTypography.Size.small)
                    .foregroundStyle(Color.ufitSecondaryText)
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
            .ufitFont(size: UFitTypography.Size.small)
            .foregroundStyle(Color.ufitSecondaryText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.action, style: .continuous))
    }
}
