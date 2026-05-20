import SwiftUI

struct FashionImage: View {
    let source: String
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let url = URL(string: source), url.scheme != nil {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder
                            .redacted(reason: .placeholder)
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                Image(source)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.ufitSecondary)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.ufitMuted)
            }
    }
}
