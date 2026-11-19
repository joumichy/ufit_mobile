import SwiftUI

extension Color {
    static let ufitInk = Color(red: 11 / 255, green: 11 / 255, blue: 12 / 255)
    static let ufitMuted = Color(red: 107 / 255, green: 114 / 255, blue: 128 / 255)
    static let ufitSecondaryText = Color(red: 75 / 255, green: 85 / 255, blue: 99 / 255)
    static let ufitSecondary = Color(red: 243 / 255, green: 244 / 255, blue: 246 / 255)
    static let ufitBorder = Color(red: 209 / 255, green: 213 / 255, blue: 219 / 255)
    static let ufitActionBorder = ufitMuted
    static let ufitCanvas = Color.white
    static let ufitBackground = ufitSecondary
    static let ufitDanger = Color(red: 153 / 255, green: 27 / 255, blue: 27 / 255)
    static let ufitDangerSurface = Color(red: 254 / 255, green: 242 / 255, blue: 242 / 255)
    static let amberText = Color(red: 120 / 255, green: 53 / 255, blue: 15 / 255)
    static let amberBackground = Color(red: 255 / 255, green: 251 / 255, blue: 235 / 255)
    static let blueText = Color(red: 30 / 255, green: 64 / 255, blue: 175 / 255)
    static let blueBackground = Color(red: 239 / 255, green: 246 / 255, blue: 255 / 255)
    static let greenText = Color(red: 6 / 255, green: 95 / 255, blue: 70 / 255)
    static let greenBackground = Color(red: 236 / 255, green: 253 / 255, blue: 245 / 255)
}

/// Photo fitting keeps a deliberate surface and readable loading/retry controls.
enum UFitPhotoSurface {
    case dark, canvas, neutral
    var background: Color {
        switch self { case .dark: .black; case .canvas: .ufitCanvas; case .neutral: .ufitSecondary }
    }
    var foreground: Color { self == .dark ? .white : .ufitInk }
}
