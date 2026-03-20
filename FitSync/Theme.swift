import SwiftUI

// MARK: - FitLog Color Palette

enum FLColor {
    static let bg         = Color(red: 0.035, green: 0.035, blue: 0.043) // zinc-950 #09090b
    static let cardBg     = Color.white.opacity(0.05)
    static let cardBorder = Color.white.opacity(0.10)
    static let cardHL     = Color.white.opacity(0.08) // highlight card
    static let borderHL   = Color.white.opacity(0.20)

    static let green      = Color(red: 0.40, green: 0.78, blue: 0.56) // muted green
    static let greenDark  = Color(red: 0.30, green: 0.68, blue: 0.46) // muted green dark
    static let amber      = Color(red: 0.98, green: 0.75, blue: 0.14) // amber-400 #fbbf24
    static let amberLight = Color(red: 0.99, green: 0.83, blue: 0.30) // amber-300 #fcd34d
    static let sky        = Color(red: 0.22, green: 0.74, blue: 0.97) // sky-400 #38bdf8
    static let red        = Color(red: 0.97, green: 0.44, blue: 0.44) // red-400 #f87171
    static let yellow     = Color(red: 0.98, green: 0.80, blue: 0.08) // yellow-400 #facc15

    static let text100    = Color.white
    static let text80     = Color.white.opacity(0.80)
    static let text60     = Color.white.opacity(0.60)
    static let text50     = Color.white.opacity(0.50)
    static let text40     = Color.white.opacity(0.40)
    static let text30     = Color.white.opacity(0.30)
    static let text20     = Color.white.opacity(0.20)
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var highlight: Bool = false
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(highlight ? FLColor.cardHL : FLColor.cardBg)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        highlight ? FLColor.borderHL : FLColor.cardBorder,
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func glassCard(highlight: Bool = false, padding: CGFloat = 20) -> some View {
        modifier(GlassCard(highlight: highlight, padding: padding))
    }
}

// MARK: - Liquid Glass Button Styles (iOS 26+)

struct GreenButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 20)
            .frame(minHeight: 56)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .glassEffect(
                .regular.tint(FLColor.green),
                in: .rect(cornerRadius: 16)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 20)
            .frame(minHeight: 56)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .glassEffect(
                .regular,
                in: .rect(cornerRadius: 16)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .glassEffect(
                .regular.tint(FLColor.red),
                in: .rect(cornerRadius: 16)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - App Background

struct AppBackground: View {
    var body: some View {
        ZStack {
            FLColor.bg.ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.10))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: -120, y: -200)

            Circle()
                .fill(Color(red: 0.05, green: 0.65, blue: 0.91).opacity(0.08))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: 140, y: 200)

            Circle()
                .fill(Color(red: 0.39, green: 0.40, blue: 0.95).opacity(0.05))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 0, y: 40)
        }
    }
}

// MARK: - Badge

struct FLBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }
}
