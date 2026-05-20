import SwiftUI

struct CreatorStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundStyle(Color.ufitMuted)
            Text(value)
                .font(.system(size: 20, weight: .medium))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.ufitMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
