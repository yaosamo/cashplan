import SwiftUI

enum AppColors {
    static let success = Color(red: 0.180, green: 0.737, blue: 0.549)
}

// MARK: - Glass Params

struct GlassParams {
    var highlightTop: Double
    var highlightBottom: Double
    var edgeTop: Double
    var edgeBottom: Double
    var strokeWidth: Double
    var s1Opacity: Double
    var s1Radius: Double
    var s1Y: Double
    var s2Opacity: Double
    var s2Radius: Double
    var s2Y: Double

    static let lightDefault = GlassParams(
        highlightTop: 0.12, highlightBottom: 0.45,
        edgeTop: 0.77, edgeBottom: 0.47, strokeWidth: 0.59,
        s1Opacity: 0.05, s1Radius: 12.10, s1Y: 3.0,
        s2Opacity: 0.10, s2Radius: 1.05,  s2Y: 0.5
    )
    static let darkDefault = GlassParams(
        highlightTop: 0.04, highlightBottom: 0.07,
        edgeTop: 0.36, edgeBottom: 0.10, strokeWidth: 0.26,
        s1Opacity: 0.05, s1Radius: 12.10, s1Y: 3.0,
        s2Opacity: 0.10, s2Radius: 1.05,  s2Y: 0.5
    )
}

// MARK: - Config

class LiquidGlassConfig: ObservableObject {
    @Published var light = GlassParams.lightDefault
    @Published var dark  = GlassParams.darkDefault

    func reset(_ scheme: ColorScheme) {
        if scheme == .dark { dark = .darkDefault } else { light = .lightDefault }
    }

    func codeSnippet() -> String {
        func f(_ v: Double) -> String { String(format: "%.2f", v) }
        func block(_ p: GlassParams, _ mode: String) -> String {
            """
            // \(mode)
            GlassParams(
                highlightTop: \(f(p.highlightTop)), highlightBottom: \(f(p.highlightBottom)),
                edgeTop: \(f(p.edgeTop)), edgeBottom: \(f(p.edgeBottom)),
                strokeWidth: \(f(p.strokeWidth)),
                s1Opacity: \(f(p.s1Opacity)), s1Radius: \(f(p.s1Radius)), s1Y: \(f(p.s1Y)),
                s2Opacity: \(f(p.s2Opacity)), s2Radius: \(f(p.s2Radius)), s2Y: \(f(p.s2Y))
            )
            """
        }
        return block(light, "Light") + "\n" + block(dark, "Dark")
    }
}

// MARK: - ViewModifier

struct LiquidGlass: ViewModifier {
    @EnvironmentObject var cfg: LiquidGlassConfig
    @Environment(\.colorScheme) var colorScheme

    var p: GlassParams { colorScheme == .dark ? cfg.dark : cfg.light }

    func body(content: Content) -> some View {
        content
            .background {
                Capsule().fill(.ultraThinMaterial)
                    .overlay { Capsule().fill(topHighlight) }
                    .overlay { Capsule().strokeBorder(edgeGlow, lineWidth: p.strokeWidth) }
            }
            .shadow(color: .black.opacity(p.s1Opacity), radius: p.s1Radius, y: p.s1Y)
            .shadow(color: .black.opacity(p.s2Opacity), radius: p.s2Radius, y: p.s2Y)
    }

    private var topHighlight: LinearGradient {
        LinearGradient(colors: [.white.opacity(p.highlightTop), .white.opacity(p.highlightBottom)],
                       startPoint: .top, endPoint: .center)
    }
    private var edgeGlow: LinearGradient {
        LinearGradient(colors: [.white.opacity(p.edgeTop), .white.opacity(p.edgeBottom)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension View {
    func liquidGlass() -> some View {
        modifier(LiquidGlass())
    }
}
