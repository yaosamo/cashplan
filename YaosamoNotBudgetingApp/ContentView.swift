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
            Capsule().fill(.ultraThinMaterial)
                .overlay { Capsule().fill(topHighlight) }
                .overlay { Capsule().strokeBorder(edgeGlow, lineWidth: p.strokeWidth) }
        case .roundedRect(let r):
            RoundedRectangle(cornerRadius: r).fill(.ultraThinMaterial)
                .overlay { RoundedRectangle(cornerRadius: r).fill(topHighlight) }
                .overlay { RoundedRectangle(cornerRadius: r).strokeBorder(edgeGlow, lineWidth: p.strokeWidth) }
        }
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
    func liquidGlass(_ shape: LiquidGlass.Shape) -> some View {
        modifier(LiquidGlass(shape: shape))
    }
}

// MARK: - Main View

struct ContentView: View {
    @EnvironmentObject var store: BudgetStore
    @State private var showSettings    = false
    @State private var showAddPurchase = false
    @State private var showTweak       = false
    @State private var showTweakBtn    = false
    @State private var tweakTapCount   = 0
    @State private var editingItem: PurchaseItem? = nil
    @State private var navDirection    = 1
    @State private var headerOffset: CGFloat = 0
    @State private var headerScale: CGFloat  = 1.0
    @State private var headerOpacity: Double = 1.0

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
                            .offset(y: headerOffset)
                            .scaleEffect(headerScale)
                            .opacity(headerOpacity)

                        Text(store.formatAmount(store.monthSpent))
                            .font(.system(size: 68, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: store.monthSpent)
                            .onTapGesture {
                                tweakTapCount += 1
                                if tweakTapCount >= 5 {
                                    tweakTapCount = 0
                                    withAnimation(.spring(response: 0.3)) { showTweakBtn = true }
                                }
                            }

                        Text(store.leftDisplay)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(.secondary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: store.leftDisplay)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 96)
                    .padding(.bottom, 72)

                    if !store.boughtInCurrentMonth.isEmpty {
                        sectionLabel("BOUGHT")
                            .padding(.bottom, 22)
                        ForEach(store.boughtInCurrentMonth) { item in
                            boughtRow(item).padding(.bottom, 24)
                        }
                        Spacer().frame(height: 32)
                    }

                    if !store.plannedItems.isEmpty {
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
                        if showTweakBtn {
                            arrowBtn("slider.horizontal.3") { showTweak = true }
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
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
                            .liquidGlass(.capsule)
                        }
                    }
                    .animation(.spring(response: 0.3), value: showTweakBtn)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                Spacer()
            }

            glassBtn("Plan Purchase", sfSymbol: "plus", fontSize: 16, hPad: 32, vPad: 16) {
                showAddPurchase = true
            }
            .padding(.bottom, 36)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(isPresented: $showSettings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddPurchase) {
            AddPurchaseSheet(isPresented: $showAddPurchase)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTweak) {
            LiquidGlassTweakSheet(isPresented: $showTweak)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingItem) { item in
            EditItemSheet(item: item)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .global)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < 0 { goNext() } else { goPrev() }
                }
        )
    }

    // MARK: - Rows

    func boughtRow(_ item: PurchaseItem) -> some View {
        BoughtRowView(item: item) { editingItem = item }
    }

    func plannedRow(_ item: PurchaseItem) -> some View {
        PlannedRowView(item: item) { editingItem = item }
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

// MARK: - Row Views

struct BoughtRowView: View {
    @EnvironmentObject var store: BudgetStore
    let item: PurchaseItem
    let onEdit: () -> Void
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 16) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                bounce.toggle()
                withAnimation(.spring(response: 0.35)) { store.unmarkBought(id: item.id) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, green)
                    .font(.system(size: 28, weight: .light))
                    .shadow(color: green.opacity(0.55), radius: 6)
                    .shadow(color: green.opacity(0.25), radius: 14)
                    .symbolEffect(.bounce, value: bounce)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 17)).foregroundColor(.primary)
                if let date = item.boughtDate {
                    Text(date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text("-\(store.formatAmount(item.amount))").font(.system(size: 17)).foregroundColor(.primary)
        }
        .contentShape(Rectangle())
        .onLongPressGesture { onEdit() }
    }
}

struct PlannedRowView: View {
    @EnvironmentObject var store: BudgetStore
    let item: PurchaseItem
    let onEdit: () -> Void
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "circle")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(Color(.tertiaryLabel))
                .symbolEffect(.bounce, value: bounce)
            Text(item.name).font(.system(size: 17)).foregroundColor(.primary)
            Spacer()
            Text(store.formatAmount(item.amount)).font(.system(size: 17)).foregroundColor(.primary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            bounce.toggle()
            withAnimation(.spring(response: 0.35)) { store.markBought(id: item.id) }
        }
        .onLongPressGesture { onEdit() }
    }
}

// MARK: - Sheet Header

struct SheetHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(.secondaryLabel))
                        .frame(width: 28, height: 28)
                        .background(Color(.systemFill))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}

// MARK: - Settings Sheet helpers

enum RecordCategory: String, Identifiable {
    case income, expense
    var id: String { rawValue }
}

struct EditingRecord: Identifiable {
    let id = UUID()
    let record: FinancialRecord
    let isIncome: Bool
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Binding var isPresented: Bool
    @State private var showCurrencyPicker = false
    @State private var addingCategory: RecordCategory? = nil
    @State private var editingRecord: EditingRecord? = nil

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Balance") { isPresented = false }
                .padding(.horizontal, 24)
                .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    recordSection(title: "INCOME",   records: store.incomeRecords,  total: store.totalIncome,   isIncome: true)
                    recordSection(title: "EXPENSES", records: store.expenseRecords, total: store.totalExpenses, isIncome: false)

                    // Currency
                    VStack(spacing: 0) {
                        Button {
                            withAnimation(.spring(response: 0.3)) { showCurrencyPicker.toggle() }
                        } label: {
                            HStack {
                                Text("Currency")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(store.currencySymbol)
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(.tertiaryLabel))
                                    .rotationEffect(.degrees(showCurrencyPicker ? 90 : 0))
                                    .animation(.spring(response: 0.3), value: showCurrencyPicker)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        if showCurrencyPicker {
                            Divider().padding(.leading, 16)
                            VStack(spacing: 0) {
                                ForEach(Array(BudgetStore.supported.enumerated()), id: \.element.id) { i, c in
                                    Button { store.currencyCode = c.code } label: {
                                        HStack {
                                            Text(c.name)
                                                .font(.system(size: 16))
                                                .foregroundColor(.primary)
                                            Spacer()
                                            if store.currencyCode == c.code {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    if i < BudgetStore.supported.count - 1 {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(item: $addingCategory) { cat in
            AddRecordSheet(isIncome: cat == .income)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingRecord) { rec in
            EditRecordSheet(record: rec.record, isIncome: rec.isIncome)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func recordSection(title: String, records: [FinancialRecord], total: Double, isIncome: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(2.5)
                    .foregroundColor(.secondary)
                Spacer()
                Button { addingCategory = isIncome ? .income : .expense } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .background(Color(.secondarySystemFill))
                        .clipShape(Circle())
                }
            }

            if records.isEmpty {
                Text("Nothing added yet")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.tertiaryLabel))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.element.id) { i, rec in
                        HStack {
                            Text(rec.name)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(store.formatAmount(rec.amount))
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .onLongPressGesture {
                            editingRecord = EditingRecord(record: rec, isIncome: isIncome)
                        }
                        if i < records.count - 1 { Divider().padding(.leading, 16) }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)

                HStack {
                    Text("Total")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(store.formatAmount(total))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Add Record Sheet

struct AddRecordSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    let isIncome: Bool
    @State private var name = ""
    @State private var amountText = ""
    @FocusState private var focused: Bool

    var canSave: Bool { !name.isEmpty && Double(amountText) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SheetHeader(title: isIncome ? "Add Income" : "Add Expense") { dismiss() }

            VStack(spacing: 10) {
                TextField(isIncome ? "Source (e.g. Salary)" : "Name (e.g. Rent)", text: $name)
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .textFieldStyle(.plain)
                    .focused($focused)

                HStack {
                    Text(store.currencySymbol).foregroundColor(.secondary).padding(.leading, 14)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 14)
                        .padding(.trailing, 14)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }

            Button {
                if let amount = Double(amountText), !name.isEmpty {
                    if isIncome { store.addIncome(name: name, amount: amount) }
                    else        { store.addExpense(name: name, amount: amount) }
                    dismiss()
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

// MARK: - Edit Record Sheet

struct EditRecordSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    let record: FinancialRecord
    let isIncome: Bool
    @State private var name: String
    @State private var amountText: String
    @FocusState private var focused: Bool

    init(record: FinancialRecord, isIncome: Bool) {
        self.record  = record
        self.isIncome = isIncome
        _name        = State(initialValue: record.name)
        _amountText  = State(initialValue: String(Int(record.amount)))
    }

    var canSave: Bool { !name.isEmpty && Double(amountText) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SheetHeader(title: "Edit") { dismiss() }

            VStack(spacing: 10) {
                TextField("Name", text: $name)
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .textFieldStyle(.plain)
                    .focused($focused)

                HStack {
                    Text(store.currencySymbol).foregroundColor(.secondary).padding(.leading, 14)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 14)
                        .padding(.trailing, 14)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }

            HStack(spacing: 12) {
                Button {
                    store.removeRecord(id: record.id, isIncome: isIncome)
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
                        store.updateRecord(id: record.id, isIncome: isIncome, name: name, amount: amount)
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
            SheetHeader(title: "Plan Purchase") { isPresented = false }

            VStack(spacing: 10) {
                TextField("What do you want to buy?", text: $name)
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .textFieldStyle(.plain)
                    .focused($focused)

                HStack {
                    Text(store.currencySymbol).foregroundColor(.secondary).padding(.leading, 14)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 14)
                        .padding(.trailing, 14)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
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
        self.item   = item
        _name       = State(initialValue: item.name)
        _amountText = State(initialValue: String(Int(item.amount)))
    }

    var canSave: Bool { !name.isEmpty && Double(amountText) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SheetHeader(title: "Edit") { dismiss() }

            VStack(spacing: 10) {
                TextField("Name", text: $name)
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .textFieldStyle(.plain)
                    .focused($focused)

                HStack {
                    Text(store.currencySymbol).foregroundColor(.secondary).padding(.leading, 14)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 14)
                        .padding(.trailing, 14)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Liquid Glass") { isPresented = false }
                .padding(.horizontal, 24)
                .padding(.top, 16)

            Picker("Mode", selection: $editScheme) {
                Text("Light").tag(ColorScheme.light)
                Text("Dark").tag(ColorScheme.dark)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 12) {
                        Spacer()
                        Button("Capsule") {}
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20).padding(.vertical, 10)
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
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .liquidGlass(.capsule)
                }
                Button {
                    withAnimation(.spring(response: 0.35)) { cfg.reset(editScheme) }
                } label: {
                    Text("Reset")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20).padding(.vertical, 12)
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
                .tracking(2).foregroundColor(.secondary)
            content()
        }
    }

    @ViewBuilder
    private func tweakRow(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 14)).foregroundColor(.primary)
                .frame(width: 54, alignment: .leading)
            Slider(value: value, in: range).tint(green)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
        }
    }
}
