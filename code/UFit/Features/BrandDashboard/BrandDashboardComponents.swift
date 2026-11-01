import SwiftUI

struct MetricCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            UFitIcon(systemName: icon)
                .ufitFont(size: UFitTypography.Size.section)
                .foregroundStyle(Color.ufitSecondaryText)
                .padding(.bottom, 2)
            Text(value)
                .ufitFont(size: UFitTypography.Size.title, weight: .regular)
            Text(label)
                .ufitFont(size: UFitTypography.Size.caption)
                .foregroundStyle(Color.ufitSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UFitSpace.md)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card, style: .continuous))
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
                .foregroundStyle(muted ? Color.ufitSecondaryText : Color.ufitInk)
            Spacer()
            Text(value)
                .ufitFont(size: valueSize, weight: .regular)
                .foregroundStyle(muted ? Color.ufitSecondaryText : Color.ufitInk)
        }
        .ufitFont(size: UFitTypography.Size.body)
    }
}

struct OrderCard: View {
    let order: BrandOrder

    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(order.id)
                        .ufitFont(size: UFitTypography.Size.small, weight: .medium)
                    Text("\(order.customer) · \(order.items) items")
                        .ufitFont(size: UFitTypography.Size.caption)
                        .foregroundStyle(Color.ufitSecondaryText)
                    Text(order.date)
                        .ufitFont(size: UFitTypography.Size.caption)
                        .foregroundStyle(Color.ufitSecondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: UFitSpace.xs) {
                    Text(order.total)
                        .ufitFont(size: UFitTypography.Size.body, weight: .medium)

                    Text(order.status.label)
                        .ufitFont(size: UFitTypography.Size.micro, weight: .medium)
                        .foregroundStyle(order.status.foreground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(order.status.background, in: Capsule())
                }
            }

            if order.status == .pending {
                HStack(spacing: 9) {
                    UFitButton {
                    } label: {
                        Label("Ship Order", systemImage: "truck.box")
                            .frame(maxWidth: .infinity)
                    }
                    .ufitButtonStyle(.primary, compact: true)

                    UFitButton {
                    } label: {
                        UFitIcon(systemName: "arrow.down.doc")
                            .ufitFont(size: UFitTypography.Size.body, weight: .medium)
                            .foregroundStyle(Color.ufitInk)
                            .frame(width: 48, height: 42)
                            .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.ufitBorder, lineWidth: 1)
                            )
                    }
                    .ufitButtonStyle(.text)
                }
            }
        }
        .padding(UFitSpace.md)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card, style: .continuous))
    }
}
