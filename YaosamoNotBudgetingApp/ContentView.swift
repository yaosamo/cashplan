import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var motion = MotionManager()

    @State private var showSettings    = false
    @State private var showAddPurchase = false
    @State private var editingItem: PurchaseItem? = nil
    @State private var headerOffset: CGFloat = 0
    @State private var headerScale: CGFloat  = 1.0
    @State private var headerOpacity: Double = 1.0
    @State private var leftShake: CGFloat = 0
#if DEBUG
    @State private var showTweak    = false
    @State private var showTweakBtn = false
    @State private var tweakTapCount = 0
#endif

    var isCurrentMonth: Bool {
        let c = Calendar.current.dateComponents([.month, .year], from: Date())
        return store.currentMonth == c.month && store.currentYear == c.year
    }

    var body: some View {
        let bg: Color = colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : Color(red: 0.94, green: 0.94, blue: 0.94)
        ZStack(alignment: .bottom) {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 4) {
                        Text("SPENT IN \(store.monthName)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(.primary)
                            .offset(y: headerOffset)
                            .scaleEffect(headerScale)
                            .opacity(headerOpacity)

                        Text(store.formatAmount(store.monthSpent))
                            .font(.system(size: 68, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: store.monthSpent)
#if DEBUG
                            .onTapGesture {
                                tweakTapCount += 1
                                if tweakTapCount >= 5 {
                                    tweakTapCount = 0
                                    withAnimation(.spring(response: 0.3)) { showTweakBtn = true }
                                }
                            }
#endif

                        Text(store.leftDisplay)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(.secondary)
                            .contentTransition(.numericText())
                            .offset(x: leftShake)
                            .onChange(of: store.isOver) { _, isOver in
                                guard isOver else { return }
                                let g = UIImpactFeedbackGenerator(style: .heavy)
                                g.prepare()
                                let offsets: [Double] = [0, 0.45, 0.53, 0.61, 0.83, 0.91]
                                for (i, t) in offsets.enumerated() {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                                        g.impactOccurred()
                                        let dir: CGFloat = i.isMultiple(of: 2) ? -6 : 6
                                        leftShake = dir
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) {
                                            leftShake = 0
                                        }
                                    }
                                }
                            }
                            .animation(.spring(response: 0.4), value: store.leftDisplay)

                        // Month progress
                        VStack(spacing: 8) {
                            GeometryReader { geo in
                                let count  = 31
                                let gap: CGFloat = 3
                                let blockW = (geo.size.width - gap * CGFloat(count - 1)) / CGFloat(count)
                                HStack(spacing: gap) {
                                    ForEach(0..<count, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Double(i) / Double(count) < store.monthProgress
                                                  ? Color.primary
                                                  : Color.primary.opacity(0.12))
                                            .frame(width: blockW, height: 8)
                                    }
                                }
                            }
                            .frame(height: 8)

                            Text("MONTH PROGRESS \(Int(store.monthProgress * 100))%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .tracking(2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 28)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 96)
                    .padding(.bottom, 72)
                    .offset(x: motion.tilt.width, y: motion.tilt.height)
                    .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.75), value: motion.tilt)

                    if !store.boughtInCurrentMonth.isEmpty {
                        sectionLabel("BOUGHT")
                            .padding(.bottom, 22)
                        ForEach(store.boughtInCurrentMonth) { item in
                            BoughtRowView(item: item) { editingItem = item }.padding(.bottom, 24)
                        }
                        Spacer().frame(height: 32)
                    }

                    if !store.plannedItems.isEmpty {
                        sectionLabel("PLAN TO BUY")
                            .padding(.bottom, 22)
                        ForEach(store.plannedItems) { item in
                            PlannedRowView(item: item) { editingItem = item }.padding(.bottom, 24)
                        }
                    }

                    Spacer(minLength: 130)
                }
                .padding(.horizontal, 24)
            }

            // Top fade — extends into status bar
            LinearGradient(
                stops: [
                    .init(color: bg,              location: 0),
                    .init(color: bg.opacity(0),   location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .frame(maxHeight: .infinity, alignment: .top)

            // Bottom fade — extends into home indicator
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    stops: [
                        .init(color: bg,              location: 0),
                        .init(color: bg.opacity(0),   location: 1)
                    ],
                    startPoint: .bottom, endPoint: .top
                )
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    HStack(spacing: 6) {
                        arrowBtn("chevron.left")  { goPrev() }
                        arrowBtn("chevron.right") { goNext() }
                        if !isCurrentMonth {
                            glassBtn("Today") { jumpToToday() }
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.3), value: isCurrentMonth)
                    Spacer()
                    HStack(spacing: 8) {
#if DEBUG
                        if showTweakBtn {
                            arrowBtn("slider.horizontal.3") { showTweak = true }
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
#endif
                        Button { showSettings = true } label: {
                            HStack(spacing: 4) {
                                Text("Balance")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                if store.totalIncome > 0 || store.totalExpenses > 0 {
                                    Text(store.formatAmount(store.balance))
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .liquidGlass()
                        }
                    }
#if DEBUG
                    .animation(.spring(response: 0.3), value: showTweakBtn)
#endif
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                Spacer()
            }

            glassBtn("Plan Purchase", sfSymbol: "plus", fontSize: 16, hPad: 32, vPad: 16) {
                showAddPurchase = true
            }
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(isPresented: $showSettings)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showAddPurchase) {
            EditItemSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingItem) { item in
            EditItemSheet(item: item)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
#if DEBUG
        .sheet(isPresented: $showTweak) {
            LiquidGlassTweakSheet(isPresented: $showTweak)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
#endif
        .simultaneousGesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .global)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < 0 { goNext() } else { goPrev() }
                }
        )
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }

    // MARK: - Buttons

    @ViewBuilder
    func arrowBtn(_ sfSymbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: sfSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 42, height: 36)
                .liquidGlass()
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
            .liquidGlass()
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

    func goNext() { animateHeader(forward: true)  { store.nextMonth() } }
    func goPrev() { animateHeader(forward: false) { store.prevMonth() } }

    func jumpToToday() {
        let c = Calendar.current.dateComponents([.month, .year], from: Date())
        let m = c.month ?? store.currentMonth
        let y = c.year  ?? store.currentYear
        let fwd = y > store.currentYear || (y == store.currentYear && m > store.currentMonth)
        animateHeader(forward: fwd) { store.currentMonth = m; store.currentYear = y }
    }

    func animateHeader(forward: Bool, change: @escaping () -> Void) {
        withAnimation(.easeIn(duration: 0.13)) {
            headerOffset  = forward ? -16 : 16
            headerScale   = 0.88
            headerOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            headerOffset  = forward ? 16 : -16
            headerScale   = 0.88
            headerOpacity = 0
            change()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                headerOffset  = 0
                headerScale   = 1
                headerOpacity = 1
            }
        }
    }
}
