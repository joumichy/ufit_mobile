import SwiftUI

struct DetailHeader<Trailing: View>: View {
    let title: String?
    let onBack: () -> Void
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String? = nil,
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.ufitInk)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)

            if let title {
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.ufitInk)
            }

            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.white.opacity(0.95))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ufitBorder)
                .frame(height: 1)
        }
    }
}
