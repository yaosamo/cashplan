import SwiftUI

// MARK: - Helpers

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

            List {
                recordSection(title: "INCOME",   records: store.incomeRecords,  total: store.totalIncome,   isIncome: true)
                recordSection(title: "EXPENSES", records: store.expenseRecords, total: store.totalExpenses, isIncome: false)

                Section {
                    Button { showCurrencyPicker = true } label: {
                        HStack {
                            Text("Currency")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(store.currencySymbol) \(store.currencyCode)")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showCurrencyPicker) {
            CurrencyPickerSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $addingCategory) { cat in
            AddRecordSheet(isIncome: cat == .income)
                .presentationDetents([.large])
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
        Section {
            ForEach(records) { rec in
                HStack {
                    Text(rec.name)
                    Spacer()
                    Text(store.formatAmount(rec.amount))
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onLongPressGesture {
                    editingRecord = EditingRecord(record: rec, isIncome: isIncome)
                }
            }
            Button { addingCategory = isIncome ? .income : .expense } label: {
                Label("Add record", systemImage: "plus")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text(title)
        } footer: {
            if !records.isEmpty {
                Text("Total \(store.formatAmount(total))")
            }
        }
    }
}

// MARK: - Currency Picker Sheet

struct CurrencyPickerSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Currency") { dismiss() }
                .padding(.horizontal, 24)
                .padding(.top, 8)

            List(BudgetStore.supported) { currency in
                Button {
                    store.currencyCode = currency.code
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Text(currency.flag)
                            .font(.system(size: 28))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(currency.name)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("\(currency.code) · \(currency.symbol)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if store.currencyCode == currency.code {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

// MARK: - Add Record Sheet

struct AddRecordSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    let isIncome: Bool
    @State private var name = ""
    @State private var input = ""
    @FocusState private var nameFocused: Bool

    var canSave: Bool {
        guard let amount = Double(input) else { return false }
        return !name.isEmpty && amount > 0 && amount.isFinite
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: isIncome ? "Add Income" : "Add Expense") { dismiss() }
                .padding(.horizontal, 24)
                .padding(.top, 8)

            TextField(isIncome ? "Source (e.g. Salary)" : "Name (e.g. Rent)", text: $name)
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .textFieldStyle(.plain)
                .focused($nameFocused)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(store.currencySymbol)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .foregroundColor(.secondary)
                Text(input.isEmpty ? "0" : input)
                    .font(.system(size: 72, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, alignment: .center)
            .onTapGesture { nameFocused = false }

            Spacer()

            numpad
                .padding(.horizontal, 16)

            Button {
                if let amount = Double(input), amount > 0, amount.isFinite, !name.isEmpty {
                    if isIncome { store.addIncome(name: name, amount: amount) }
                    else        { store.addExpense(name: name, amount: amount) }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    dismiss()
                }
            } label: {
                Text("Add")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(canSave ? Color(.systemBackground) : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSave ? Color(.label) : Color(.tertiarySystemFill))
                    .cornerRadius(14)
                    .animation(.easeInOut(duration: 0.15), value: canSave)
            }
            .disabled(!canSave)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 36)
        }
    }

    private var numpad: some View {
        VStack(spacing: 10) {
            ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { n in numKey("\(n)") { tap("\(n)") } }
                }
            }
            HStack(spacing: 10) {
                numKey(".") { tapDot() }
                numKey("0") { tap("0") }
                numKey("⌫") { tapBack() }
            }
        }
    }

    func tap(_ d: String) {
        nameFocused = false
        guard input.count < 10 else { return }
        if d == "0" && input.isEmpty { return }
        input += d
    }

    func tapDot() {
        nameFocused = false
        guard !input.contains(".") else { return }
        input += input.isEmpty ? "0." : "."
    }

    func tapBack() {
        guard !input.isEmpty else { return }
        input.removeLast()
    }

    @ViewBuilder
    func numKey(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: label == "⌫" ? 20 : 26, weight: .regular))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
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
        self.record   = record
        self.isIncome = isIncome
        _name         = State(initialValue: record.name)
        _amountText   = State(initialValue: String(Int(record.amount)))
    }

    var canSave: Bool {
        guard let amount = Double(amountText) else { return false }
        return !name.isEmpty && amount > 0 && amount.isFinite
    }

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
                    if let amount = Double(amountText), amount > 0, amount.isFinite, !name.isEmpty {
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
