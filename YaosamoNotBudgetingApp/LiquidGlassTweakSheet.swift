#if DEBUG
import SwiftUI

struct LiquidGlassTweakSheet: View {
    @EnvironmentObject var cfg: LiquidGlassConfig
    @Binding var isPresented: Bool
    @State private var editScheme: ColorScheme = .light
    @State private var copied = false

    private var paramsBinding: Binding<GlassParams> {
        editScheme == .dark ? $cfg.dark : $cfg.light
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Liquid Glass") { isPresented = false }

            Picker("Mode", selection: $editScheme) {
                Text("Light").tag(ColorScheme.light)
                Text("Dark").tag(ColorScheme.dark)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    buttonsControls
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = cfg.codeSnippet()
                    withAnimation(.spring(response: 0.3)) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.spring(response: 0.3)) { copied = false }
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy Both", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .liquidGlass()
                }
                Button {
                    withAnimation(.spring(response: 0.35)) { cfg.reset(editScheme) }
                } label: {
                    Text("Reset")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .liquidGlass()
                }
            }
            .padding(.bottom, 40)
        }
    }

    private var buttonsControls: some View {
        Group {
            HStack(spacing: 12) {
                Spacer()
                Text("Capsule")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .liquidGlass()
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 42, height: 36)
                    .liquidGlass()
                Spacer()
            }
            .padding(.vertical, 12)
            .background(editScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
            .cornerRadius(16)
            .environment(\.colorScheme, editScheme)

            tweakSection("HIGHLIGHT") {
                tweakRow("Top", paramsBinding.highlightTop, 0...1)
                tweakRow("Bottom", paramsBinding.highlightBottom, 0...1)
            }
            tweakSection("EDGE GLOW") {
                tweakRow("Top", paramsBinding.edgeTop, 0...1)
                tweakRow("Bottom", paramsBinding.edgeBottom, 0...1)
                tweakRow("Stroke", paramsBinding.strokeWidth, 0...4)
            }
            tweakSection("OUTER SHADOW") {
                tweakRow("Opacity", paramsBinding.s1Opacity, 0...0.5)
                tweakRow("Radius", paramsBinding.s1Radius, 0...30)
                tweakRow("Y", paramsBinding.s1Y, 0...20)
            }
            tweakSection("INNER SHADOW") {
                tweakRow("Opacity", paramsBinding.s2Opacity, 0...0.5)
                tweakRow("Radius", paramsBinding.s2Radius, 0...10)
                tweakRow("Y", paramsBinding.s2Y, 0...10)
            }
        }
    }

    @ViewBuilder
    private func tweakSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(2).foregroundColor(.secondary)
            content()
        }
    }

    @ViewBuilder
    private func tweakRow(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 14)).foregroundColor(.primary)
                .frame(width: 54, alignment: .leading)
            Slider(value: value, in: range).tint(AppColors.success)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
        }
    }
}
#endif
