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
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Color.clear.frame(height: 72)

                    Text(store.formatBalanceAmount(store.balance))
                        .font(.system(size: 48, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)

                    VStack(alignment: .leading, spacing: 12) {
                        recordSection(title: "INCOME",   records: store.activeIncomeRecords, total: store.totalIncome, isIncome: true)

                        VStack(spacing: 0) {
                            Toggle(isOn: $store.clearIncomeMonthly) {
                                Text("Clear income every month")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                            }
                            .tint(AppColors.success)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(14)
                    }

                    recordSection(title: "EXPENSES", records: store.expenseRecords, total: store.totalExpenses, isIncome: false)

                    VStack(spacing: 0) {
                        Button { showCurrencyPicker = true } label: {
                            HStack {
                                Text("Currency")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(store.currencySymbol) \(store.currencyCode)")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(.tertiaryLabel))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                    }
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 96)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.5),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
            }

            SheetHeader(title: "Monthly Balance") { isPresented = false }
        }
        .background(Color(.secondarySystemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showCurrencyPicker) {
            CurrencyPickerSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $addingCategory) { cat in
            EditRecordSheet(isIncome: cat == .income)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingRecord) { rec in
            EditRecordSheet(record: rec.record, isIncome: rec.isIncome)
                .presentationDetents([.large])
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
                Text(store.formatAmount(total))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(records.enumerated()), id: \.element.id) { _, rec in
                    HStack {
                        Text(rec.name)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(store.formatAmount(isIncome ? rec.monthlyAmount : rec.amount))
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            if isIncome && rec.cadence != .monthly {
                                Text("\(store.formatAmount(rec.amount)) \(rec.cadence.label.lowercased())")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingRecord = EditingRecord(record: rec, isIncome: isIncome)
                    }
                    Divider().padding(.leading, 16)
                }

                Button { addingCategory = isIncome ? .income : .expense } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(.tertiaryLabel))
                        Text("Add record")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

            }
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(14)

        }
    }
}

// MARK: - Currency Picker Sheet

struct CurrencyPickerSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredCurrencies: [Currency] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return BudgetStore.supported }

        return BudgetStore.supported.filter { currency in
            currency.name.localizedCaseInsensitiveContains(query) ||
            currency.code.localizedCaseInsensitiveContains(query) ||
            currency.symbol.localizedCaseInsensitiveContains(query) ||
            currency.flag.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            List {
                if filteredCurrencies.isEmpty {
                    Text("No currencies found")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 28)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredCurrencies) { currency in
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
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 128)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 152)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.5),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                SheetHeader(title: "Currency") { dismiss() }
                CurrencySearchField(text: $searchText)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
            }
        }
        .background(Color(.secondarySystemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct CurrencySearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            TextField("Search", text: $text)
                .font(.system(size: 16))
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Edit / Add Record Sheet

struct EditRecordSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    let record: FinancialRecord?
    let isIncome: Bool
    @State private var input: String
    @State private var name: String
    @State private var cadence: IncomeCadence
    @State private var payday: Date
    @State private var showAmountSheet = false
    @State private var showPaydayPicker = false
    @FocusState private var nameFocused: Bool

    init(record: FinancialRecord? = nil, isIncome: Bool) {
        self.record   = record
        self.isIncome = isIncome
        _input = State(initialValue: record.map { MoneyInput.editableString($0.amount) } ?? "")
        _name  = State(initialValue: record?.name ?? "")
        _cadence = State(initialValue: record?.cadence ?? .monthly)
        _payday = State(initialValue: record?.payday ?? Date())
    }

    private var isAdding: Bool { record == nil }

    var canSave: Bool {
        guard let amount = Double(input) else { return false }
        return amount > 0 && amount.isFinite && !name.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: isAdding ? (isIncome ? "Add Income" : "Add Expense") : "Edit",
                onClose: { dismiss() },
                onDelete: isAdding ? nil : {
                    if let record { store.removeRecord(id: record.id, isIncome: isIncome) }
                    dismiss()
                }
            )

            Spacer()

            TextField(isIncome ? "Income" : "Expense", text: $name)
                .font(.system(size: 48, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.35)
                .lineLimit(1)
                .padding(.horizontal, 32)
                .focused($nameFocused)
                .submitLabel(.done)
                .onAppear { nameFocused = true }

            Spacer()

            Button { showAmountSheet = true } label: {
                HStack {
                    Text("Amount")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(store.formatCurrencyInput(input))
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .padding(.horizontal, 16)

            if isIncome {
                HStack {
                    Text("Cadence")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Spacer()
                    Menu {
                        Picker("Cadence", selection: $cadence) {
                            ForEach(IncomeCadence.allCases) { cadence in
                                Text(cadence.label).tag(cadence)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Spacer(minLength: 0)
                            Text(cadence.label)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .frame(minWidth: 110, alignment: .trailing)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Button { showPaydayPicker = true } label: {
                    HStack {
                        Text("Payday")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(payday.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Image(systemName: "calendar")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            Spacer().frame(height: 16)

            Button {
                if canSave, let amount = Double(input) {
                    if isAdding {
                        if isIncome { store.addIncome(name: name, amount: amount, cadence: cadence, payday: payday) }
                        else        { store.addExpense(name: name, amount: amount) }
                    } else if let record {
                        store.updateRecord(id: record.id, isIncome: isIncome, name: name, amount: amount, cadence: cadence, payday: payday)
                    }
                    dismiss()
                } else {
                    showAmountSheet = true
                }
            } label: {
                Text(canSave ? (isAdding ? "Add" : "Save") : "Next")
                    .font(.headline)
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Color(.label))
                    .cornerRadius(14)
                    .animation(.easeInOut(duration: 0.15), value: canSave)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .sheet(isPresented: $showAmountSheet) {
            AmountEntrySheet(input: $input)
                .presentationDetents([.fraction(0.58)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showPaydayPicker) {
            PaydayPickerSheet(payday: $payday)
                .presentationDetents([.fraction(0.68)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }
}

struct PaydayPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var payday: Date

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Payday") { dismiss() }

            DatePicker("Payday", selection: $payday, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .tint(AppColors.success)
                .labelsHidden()
                .padding(.horizontal, 16)

            Spacer(minLength: 12)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Color(.label))
                    .cornerRadius(14)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(Color(.secondarySystemBackground))
    }
}
