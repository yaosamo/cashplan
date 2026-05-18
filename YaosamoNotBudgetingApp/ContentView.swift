import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var motion = MotionManager()

    @State private var showSettings    = false
    @State private var showAnalytics   = false
    @State private var showAddPurchase = false
    @State private var editingItem: PurchaseItem? = nil
    @State private var headerOffset: CGFloat = 0
    @State private var headerScale: CGFloat  = 1.0
    @State private var headerOpacity: Double = 1.0
    @State private var leftShake: CGFloat = 0
    @State private var squaresVisible: Bool = false
    @State private var topMarkerOffset: CGFloat = 0
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
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: proxy.frame(in: .named("homeScroll")).minY
                        )
                }
                .frame(height: 0)

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

                        HStack(spacing: 6) {
                            if store.isOver {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .transition(.scale(scale: 0.82).combined(with: .opacity))
                            }
                            Text(store.leftDisplay)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .tracking(2)
                                .contentTransition(.numericText())
                                .offset(x: leftShake)
                        }
                            .foregroundColor(.secondary)
                            .onChange(of: store.isOver) { _, isOver in
                                guard isOver else { return }
                                let g = UINotificationFeedbackGenerator()
                                g.prepare()
                                g.notificationOccurred(.warning)

                                let shakes: [(delay: Double, offset: CGFloat)] = [
                                    (0.00, -4),
                                    (0.08, 4),
                                    (0.16, -2),
                                    (0.24, 0)
                                ]
                                for shake in shakes {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + shake.delay) {
                                        withAnimation(.easeOut(duration: 0.08)) {
                                            leftShake = shake.offset
                                        }
                                    }
                                }
                            }
                            .animation(.spring(response: 0.4), value: store.leftDisplay)
                            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: store.isOver)

                        // Month progress
                        VStack(spacing: 8) {
                            HStack(spacing: 2) {
                                ForEach(0..<store.daysInCurrentMonth, id: \.self) { i in
                                    let day = i + 1
                                    let isSalaryPayday = store.salaryPaydaysInCurrentMonth.contains(day)
                                    ZStack {
                                        Rectangle()
                                            .fill(monthProgressColor(index: i))
                                        if isSalaryPayday {
                                            Circle()
                                                .fill(salaryPaydayDotColor(index: i))
                                                .frame(width: 4, height: 4)
                                                .shadow(color: .black.opacity(0.18), radius: 2)
                                        }
                                    }
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(squaresVisible ? 1 : 0.01, anchor: .bottom)
                                        .opacity(squaresVisible ? 1 : 0)
                                        .animation(
                                            .spring(response: 0.32, dampingFraction: 0.52)
                                            .delay(Double(i) * 0.022),
                                            value: squaresVisible
                                        )
                                }
                            }
                            .onAppear { squaresVisible = true }

                            Text("MONTH PROGRESS \(Int(store.monthProgress * 100))%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .tracking(2)
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 44)
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
                .background(alignment: .top) {
                    HeaderBarsObject(spendingProgress: headerSpendingProgress)
                        .frame(width: 210, height: 210)
                        .rotationEffect(.degrees(45))
                        .scaleEffect(headerBarsPullScale)
                        .saturation(1.25)
                        .blur(radius: 26)
                        .offset(y: headerBarsYOffset)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "homeScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { topMarkerOffset = $0 }

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
                                    .layoutPriority(1)
                                if store.totalIncome > 0 || store.totalExpenses > 0 {
                                    Text(store.formatBalanceAmount(store.balance))
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: balanceChipAmountMaxWidth, alignment: .trailing)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showSettings) {
            SettingsSheet(isPresented: $showSettings)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showAnalytics) {
            AnalyticsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
                    let h = value.translation.height
                    let w = value.translation.width
                    if abs(h) > abs(w) {
                        if h > 60 && value.startLocation.y < 220 { showAnalytics = true }
                    } else {
                        if w < 0 { goNext() } else { goPrev() }
                    }
                }
        )
        .onAppear {
            motion.start()
        }
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

    var balanceChipAmountMaxWidth: CGFloat? {
        UIScreen.main.bounds.width < 380 ? 72 : nil
    }

    var headerBarsPullDistance: CGFloat {
        min(max(topMarkerOffset, 0), 120)
    }

    var headerBarsPullScale: CGFloat {
        1 + headerBarsPullDistance / 240
    }

    var headerBarsYOffset: CGFloat {
        -153 - headerBarsPullDistance * 0.7
    }

    var headerSpendingProgress: CGFloat {
        guard store.balance > 0 else {
            return store.monthSpent > 0 ? 1 : 0
        }
        return min(max(CGFloat(store.monthSpent / store.balance), 0), 1)
    }

    func monthProgressColor(index: Int) -> Color {
        return Double(index) / Double(store.daysInCurrentMonth) < store.monthProgress
            ? Color.primary
            : Color.primary.opacity(0.12)
    }

    func salaryPaydayDotColor(index: Int) -> Color {
        let isFilledDay = Double(index) / Double(store.daysInCurrentMonth) < store.monthProgress
        guard isFilledDay else { return Color.primary.opacity(0.46) }
        return colorScheme == .dark ? Color.black.opacity(0.58) : Color.white.opacity(0.88)
    }

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
            squaresVisible = false
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                headerOffset  = 0
                headerScale   = 1
                headerOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                squaresVisible = true
            }
        }
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct HeaderBarsObject: View {
    let spendingProgress: CGFloat

    private let bars: [(color: Color, baseHeight: CGFloat)] = [
        (Color(red: 0.62, green: 0.58, blue: 0.84), 0.49),
        (Color(red: 0.94, green: 0.74, blue: 0.73), 0.24),
        (Color(red: 1.00, green: 0.85, blue: 0.39), 0.11),
        (Color(red: 0.84, green: 0.96, blue: 0.55), 0.16)
    ]

    var body: some View {
        GeometryReader { geo in
            bandStack(size: geo.size)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                }
        }
    }

    private func bandStack(size: CGSize) -> some View {
        let heights = segmentHeights()

        return VStack(spacing: 0) {
            ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                bar.color
                    .frame(height: size.height * heights[index])
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(index == 0 ? 0.16 : 0.08),
                                Color.black.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func segmentHeights() -> [CGFloat] {
        let progress = min(max(spendingProgress, 0), 1)
        let calmHeights: [CGFloat] = [0.25, 0.25, 0.25, 0.25]
        let spentHeights: [CGFloat] = [0.52, 0.25, 0.15, 0.08]
        let blend = progress <= 0.10 ? 0 : (progress - 0.10) / 0.90
        let baseHeights = zip(calmHeights, spentHeights).map { calm, spent in
            calm + (spent - calm) * blend
        }

        let total = baseHeights.reduce(0, +)
        return baseHeights.map { $0 / total }
    }
}
