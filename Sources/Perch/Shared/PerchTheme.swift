import SwiftUI

enum PerchPalette {
    static let accent = Color(red: 0.878, green: 0.471, blue: 0.251)
    static let blueAccent = Color(red: 0.239, green: 0.482, blue: 0.878)
    static let background = Color(red: 0.969, green: 0.949, blue: 0.929)
    static let surface = Color.white
    static let secondarySurface = Color(red: 0.941, green: 0.922, blue: 0.898)
    static let text = Color(red: 0.102, green: 0.090, blue: 0.078)
    static let muted = Color(red: 0.604, green: 0.553, blue: 0.514)
    static let gain = Color(red: 0.239, green: 0.729, blue: 0.471)
    static let loss = Color(red: 0.851, green: 0.373, blue: 0.373)
}

extension ShapeStyle where Self == Color {
    static var perchBackground: Color { PerchPalette.background }
    static var perchSurface: Color { PerchPalette.surface }
    static var perchSecondarySurface: Color { PerchPalette.secondarySurface }
    static var perchAccent: Color { PerchPalette.accent }
    static var perchText: Color { PerchPalette.text }
    static var perchMuted: Color { PerchPalette.muted }
}

struct PerchCardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.perchSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
    }
}

extension View {
    func perchCard(padding: CGFloat = 16) -> some View {
        modifier(PerchCardModifier(padding: padding))
    }
}
