import SwiftUI

/// SF Symbols are the icon source; sizing, contrast and accessibility belong to Ufit.
struct UFitIcon: View {
    let systemName: String
    var body: some View { Image(systemName: systemName).symbolRenderingMode(.monochrome) }
}
