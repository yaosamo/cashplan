import SwiftUI

private let green = Color(red: 0.180, green: 0.737, blue: 0.549)

// MARK: - Liquid Glass Config

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
        edgeTop: 0.77, edgeBottom: 0.47,
        strokeWidth: 0.59,
        s1Opacity: 0.05, s1Radius: 12.10, s1Y: 3.0,
        s2Opacity: 0.10, s2Radius: 1.05,  s2Y: 0.5
    )

    static let darkDefault = GlassParams(
        highlightTop: 0.04, highlightBottom: 0.07,
        edgeTop: 0.36, edgeBottom: 0.10,
        strokeWidth: 0.26,
        s1Opacity: 0.05, s1Radius: 12.10, s1Y: 3.0,
        s2Opacity: 0.10, s2Radius: 1.05,  s2Y: 0.5
    )
}

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

// MARK: - Liquid Glass

struct LiquidGlass: ViewModifier {
    enum Shape { case capsule, roundedRect(CGFloat) }
    let shape: Shape
    @EnvironmentObject var cfg: LiquidGlassConfig
    @Environment(\.colorScheme) var colorScheme

    var p: GlassParams { colorScheme == .dark ? cfg.dark : cfg.light }

    func body(content: Content) -> some View {
        content
            .background { glassBackground }
            .shadow(color: .black.opacity(p.s1Opacity), radius: p.s1Radius, y: p.s1Y)
            .shadow(color: .black.opacity(p.s2Opacity), radius: p.s2Radius, y: p.s2Y)
    }

    @ViewBuilder
    private var glassBackground: some View {
        switch shape {
        case .capsule:
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay { Capsule().fill(topHighlight) }
                .overlay { Capsule().strokeBorder(edgeGlow, lineWidth: p.strokeWidth) }
        case .roundedRect(let r):
            RoundedRectangle(cornerRadius: r)
                .fill(.ultraThinMaterial)
                .overlay { RoundedRectangle(cornerRadius: r).fill(topHighlight) }
                .overlay { RoundedRectangle(cornerRadius: r).strokeBorder(edgeGlow, lineWidth: p.strokeWidth) }
        }
    }

    private var topHighlight: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(p.highlightTop), .white.opacity(p.highlightBottom)],
            startPoint: .top, endPoint: .center
        )
    }

    private var edgeGlow: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(p.edgeTop), .white.opacity(p.edgeBottom)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

extension View {
    func liquidGlass(_ shape: LiquidGlass.Shape) -> some View {
        modifier(LiquidGlass(shape: shape))
    }
}

// MARK: - Main View

struct ContentView: View {
    @EnvironmentObject var store: BudgetStore
    @State private var showSetBalance  = false
    @State private var showAddPurchase = false
    @State private var showTweak       = false
    @State private var showTweakBtn    = false
    @State private var tweakTapCount   = 0
    @State private var editingItem: PurchaseItem? = nil

    var isCurrentMonth: Bool {
        let c = Calendar.current.dateComponents([.month, .year], from: Date())
        return store.currentMonth == c.month && store.currentYear == c.year
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.secondarySystemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    VStack(spacing: 4) {
                        Text(store.monthYearLabel)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(.primary)

                        Text(store.netDisplay)
                            .font(.system(size: 68, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: store.netDisplay)
                            .onTapGesture {
                                tweakTapCount += 1
                                if tweakTapCount >= 5 {
                                    tweakTapCount = 0
                                    withAnimation(.spring(response: 0.3)) { showTweakBtn = true }
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 96)
                    .padding(.bottom, 72)

                    if !store.boughtInCurrentMonth.isEmpty {
                        sectionLabel("BOUGHT IN \(store.monthName)")
                            .padding(.bottom, 22)
                        ForEach(store.boughtInCurrentMonth) { item in
                            boughtRow(item).padding(.bottom, 24)
                        }
                        Spacer().frame(height: 32)
                    }

                    if isCurrentMonth && !store.plannedItems.isEmpty {
                        sectionLabel("PLAN TO BUY")
                            .padding(.bottom, 22)
                        ForEach(store.plannedItems) { item in
                            plannedRow(item).padding(.bottom, 24)
                        }
                    }

                    Spacer(minLength: 130)
                }
                .padding(.horizontal, 24)
            }

            VStack {
                HStack {
                    HStack(spacing: 6) {
                        arrowBtn("chevron.left")  { store.prevMonth() }
                        arrowBtn("chevron.right") { store.nextMonth() }
                        if !isCurrentMonth {
                            glassBtn("Today") { jumpToToday() }
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.3), value: isCurrentMonth)
                    Spacer()
                    HStack(spacing: 8) {
                        if showTweakBtn {
                            arrowBtn("slider.horizontal.3") { showTweak = true }
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                        glassBtn("Set Balance") { showSetBalance = true }
                    }
                    .animation(.spring(response: 0.3), value: showTweakBtn)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                Spacer()
            }

            glassBtn("Plan Purchase", sfSymbol: "plus", fontSize: 16, hPad: 32, vPad: 16) { showAddPurchase = true }
                .padding(.bottom, 36)
        }
        .sheet(isPresented: $showSetBalance) {
            SetBalanceSheet(isPresented: $showSetBalance)
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showAddPurchase) {
            AddPurchaseSheet(isPresented: $showAddPurchase)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showTweak) {
            LiquidGlassTweakSheet(isPresented: $showTweak)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingItem) { item in
            EditItemSheet(item: item)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    // MARK: - Rows

    @ViewBuilder
    func boughtRow(_ item: PurchaseItem) -> some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.35)) { store.unmarkBought(id: item.id) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, green)
                    .font(.system(size: 28, weight: .light))
                    .shadow(color: green.opacity(0.55), radius: 6)
                    .shadow(color: green.opacity(0.25), radius: 14)
            }
            Text(item.name).font(.system(size: 17)).foregroundColor(.primary)
            Spacer()
            Text("-\(fmt(item.amount))").font(.system(size: 17)).foregroundColor(.primary)
        }
        .contentShape(Rectangle())
        .onLongPressGesture { editingItem = item }
    }

    @ViewBuilder
    func plannedRow(_ item: PurchaseItem) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "circle")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(Color(.tertiaryLabel))
            Text(item.name).font(.system(size: 17)).foregroundColor(.primary)
            Spacer()
            Text(fmt(item.amount)).font(.system(size: 17)).foregroundColor(.primary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35)) { store.markBought(id: item.id) }
        }
        .onLongPressGesture { editingItem = item }
    }

    // MARK: - Buttons

    @ViewBuilder
    func arrowBtn(_ sfSymbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: sfSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 42, height: 36)
                .liquidGlass(.capsule)
        }
    }

    @ViewBuilder
    func glassBtn(_ title: String, sfSymbol: String? = nil, fontSize: CGFloat = 15, hPad: CGFloat = 18, vPad: CGFloat = 10, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol = sfSymbol {
                    Image(systemName: symbol).font(.system(size: fontSize - 1, weight: .medium))
                }
                Text(title).font(.system(size: fontSize, weight: .medium))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .liquidGlass(.capsule)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(2.5)
            .foregroundColor(.secondary)
    }

    func fmt(_ amount: Double) -> String { "$\(Int(amount))" }

    func jumpToToday() {
        let c = Calendar.current.dateComponents([.month, .year], from: Date())
        withAnimation(.spring(response: 0.4)) {
            store.currentMonth = c.month ?? store.currentMonth
            store.currentYear  = c.year  ?? store.currentYear
        }
    }
}

// MARK: - Set Balance Sheet

struct SetBalanceSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Binding var isPresented: Bool
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Set Balance")
                .font(.title2.bold())
                .foregroundColor(.primary)
                .padding(.top, 4)

            HStack {
                Text("$")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.secondary)
                TextField("0", text: $text)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .focused($focused)
            }
            .padding(16)
            .background(.regularMaterial)
            .cornerRadius(14)
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.25), lineWidth: 0.75) }

            Button {
                store.balance = Double(text) ?? 0
                isPresented = false
            } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(.label))
                    .cornerRadius(14)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            if store.balance > 0 { text = "\(Int(store.balance))" }
            focused = true
        }
    }
}

// MARK: - Add Purchase Sheet

struct AddPurchaseSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var amountText = ""
    @FocusState private var focused: Bool

    var canSave: Bool { !name.isEmpty && Double(amountText) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Plan Purchase")
                .font(.title2.bold())
                .foregroundColor(.primary)
                .padding(.top, 4)

            VStack(spacing: 10) {
                TextField("What do you want to buy?", text: $name)
                    .padding(14)
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.25), lineWidth: 0.75) }
                    .textFieldStyle(.plain)
                    .focused($focused)

                HStack {
                    Text("$").foregroundColor(.secondary).padding(.leading, 14)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 14)
                        .padding(.trailing, 14)
                }
                .background(.regularMaterial)
                .cornerRadius(12)
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.25), lineWidth: 0.75) }
            }

            Button {
                if let amount = Double(amountText), !name.isEmpty {
                    store.addItem(name: name, amount: amount)
                    isPresented = false
                }
            } label: {
                Text("Add")
                    .font(.headline)
                    .foregroundColor(canSave ? Color(.systemBackground) : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(canSave ? Color(.label) : Color(.tertiarySystemFill))
                    .cornerRadius(14)
                    .animation(.easeInOut(duration: 0.15), value: canSave)
            }
            .disabled(!canSave)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { focused = true }
    }
}

// MARK: - Edit Item Sheet

struct EditItemSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    let item: PurchaseItem
    @State private var name: String
    @State private var amountText: String
    @FocusState private var focused: Bool

    init(item: PurchaseItem) {
        self.item = item
        _name       = State(initialValue: item.name)
        _amountText = State(initialValue: String(Int(item.amount)))
    }

    var canSave: Bool { !name.isEmpty && Double(amountText) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit")
                .font(.title2.bold())
                .foregroundColor(.primary)
                .padding(.top, 4)

            VStack(spacing: 10) {
                TextField("Name", text: $name)
                    .padding(14)
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.25), lineWidth: 0.75) }
                    .textFieldStyle(.plain)
                    .focused($focused)

                HStack {
                    Text("$").foregroundColor(.secondary).padding(.leading, 14)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 14)
                        .padding(.trailing, 14)
                }
                .background(.regularMaterial)
                .cornerRadius(12)
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.25), lineWidth: 0.75) }
            }

            HStack(spacing: 12) {
                Button {
                    store.removeItem(id: item.id)
                    dismiss()
                } label: {
                    Text("Delete")
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color(.tertiarySystemFill))
                        .cornerRadius(14)
                }

                Button {
                    if let amount = Double(amountText), !name.isEmpty {
                        store.updateItem(id: item.id, name: name, amount: amount)
                        dismiss()
                    }
                } label: {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(canSave ? Color(.systemBackground) : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(canSave ? Color(.label) : Color(.tertiarySystemFill))
                        .cornerRadius(14)
                        .animation(.easeInOut(duration: 0.15), value: canSave)
                }
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { focused = true }
    }
}

// MARK: - Liquid Glass Tweak Sheet

struct LiquidGlassTweakSheet: View {
    @EnvironmentObject var cfg: LiquidGlassConfig
    @Binding var isPresented: Bool
    @State private var editScheme: ColorScheme = .light
    @State private var copied = false

    private var paramsBinding: Binding<GlassParams> {
        editScheme == .dark ? $cfg.dark : $cfg.light
    }
    private var params: GlassParams {
        editScheme == .dark ? cfg.dark : cfg.light
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Liquid Glass")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { isPresented = false }
                    .font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Light / Dark picker
            Picker("Mode", selection: $editScheme) {
                Text("Light").tag(ColorScheme.light)
                Text("Dark").tag(ColorScheme.dark)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Live preview forced into the editing scheme
                    HStack(spacing: 12) {
                        Spacer()
                        Button("Capsule") {}
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .liquidGlass(.capsule)
                        Button {} label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 42, height: 36)
                                .liquidGlass(.capsule)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(editScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                    .cornerRadius(16)
                    .environment(\.colorScheme, editScheme)

                    tweakSection("HIGHLIGHT") {
                        tweakRow("Top",    paramsBinding.highlightTop,    0...1)
                        tweakRow("Bottom", paramsBinding.highlightBottom, 0...1)
                    }

                    tweakSection("EDGE GLOW") {
                        tweakRow("Top",    paramsBinding.edgeTop,     0...1)
                        tweakRow("Bottom", paramsBinding.edgeBottom,  0...1)
                        tweakRow("Stroke", paramsBinding.strokeWidth, 0...4)
                    }

                    tweakSection("OUTER SHADOW") {
                        tweakRow("Opacity", paramsBinding.s1Opacity, 0...0.5)
                        tweakRow("Radius",  paramsBinding.s1Radius,  0...30)
                        tweakRow("Y",       paramsBinding.s1Y,       0...20)
                    }

                    tweakSection("INNER SHADOW") {
                        tweakRow("Opacity", paramsBinding.s2Opacity, 0...0.5)
                        tweakRow("Radius",  paramsBinding.s2Radius,  0...10)
                        tweakRow("Y",       paramsBinding.s2Y,       0...10)
                    }
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
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .liquidGlass(.capsule)
                }

                Button {
                    withAnimation(.spring(response: 0.35)) { cfg.reset(editScheme) }
                } label: {
                    Text("Reset")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .liquidGlass(.capsule)
                }
            }
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func tweakSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundColor(.secondary)
            content()
        }
    }

    @ViewBuilder
    private func tweakRow(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .frame(width: 54, alignment: .leading)
            Slider(value: value, in: range)
                .tint(green)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}
