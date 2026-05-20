import SwiftUI

struct BrandDashboardView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(title: "Brand Dashboard", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    BrandDashboardHeader()
                    BrandMetricsSection()
                    RevenueSummaryCard()
                    RecentOrdersSection(orders: SampleData.orders)
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

private struct BrandDashboardHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Atelier Minimal")
                .font(.system(size: 28, weight: .regular))
            Text("Independent Fashion Brand")
                .font(.system(size: 14))
                .foregroundStyle(Color.ufitMuted)
        }
    }
}

private struct BrandMetricsSection: View {
    var body: some View {
        HStack(spacing: 14) {
            MetricCard(icon: "shippingbox", value: "24", label: "Pending Orders")
            MetricCard(icon: "eurosign.circle", value: "8,942€", label: "This Month")
        }
    }
}

private struct RevenueSummaryCard: View {
    var body: some View {
        VStack(spacing: 13) {
            DashboardRow(label: "Total Revenue (Mai)", value: "8,942€", valueSize: 22)
            DashboardRow(label: "Commission UFit (8%)", value: "-715€", muted: true)
            Divider()
            DashboardRow(label: "Net Revenue", value: "8,227€", valueSize: 22)
        }
        .padding(18)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

#Preview {
    BrandDashboardView(onBack: {})
}
