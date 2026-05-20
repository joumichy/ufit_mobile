import SwiftUI

struct MetricCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.ufitMuted)
                .padding(.bottom, 2)
            Text(value)
                .font(.system(size: 25, weight: .regular))
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.ufitMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct DashboardRow: View {
    let label: String
    let value: String
    var muted = false
    var valueSize: CGFloat = 16

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(muted ? Color.ufitMuted : Color.ufitInk)
            Spacer()
            Text(value)
                .font(.system(size: valueSize, weight: .regular))
                .foregroundStyle(muted ? Color.ufitMuted : Color.ufitInk)
        }
        .font(.system(size: 15))
    }
}

struct OrderCard: View {
    let order: BrandOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(order.id)
                        .font(.system(size: 14, weight: .medium))
                    Text("\(order.customer) · \(order.items) items")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ufitMuted)
                    Text(order.date)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ufitMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(order.total)
                        .font(.system(size: 16, weight: .medium))

                    Text(order.status.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(order.status.foreground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(order.status.background, in: Capsule())
                }
            }

            if order.status == .pending {
                HStack(spacing: 9) {
                    Button {
                    } label: {
                        Label("Ship Order", systemImage: "truck.box")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompactPrimaryButtonStyle())

                    Button {
                    } label: {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.ufitInk)
                            .frame(width: 48, height: 42)
                            .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.ufitBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
