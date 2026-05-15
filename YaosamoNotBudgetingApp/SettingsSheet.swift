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

                    Text(store.formatAmount(store.balance))
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
                        Text(store.formatAmount(rec.amount))
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
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

    var body: some View {
        ZStack(alignment: .top) {
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
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 72)
            }
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

            SheetHeader(title: "Currency") { dismiss() }
        }
        .background(Color(.secondarySystemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
    @State private var showAmountSheet = false
    @FocusState private var nameFocused: Bool

    init(record: FinancialRecord? = nil, isIncome: Bool) {
        self.record   = record
        self.isIncome = isIncome
        _input = State(initialValue: record.map { MoneyInput.editableString($0.amount) } ?? "")
        _name  = State(initialValue: record?.name ?? "")
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

            TextField("–", text: $name)
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
                    Text(input.isEmpty ? "–" : "\(store.currencySymbol)\(numpadDisplay(input))")
                        .font(.system(size: 16))
                        .foregroundColor(input.isEmpty ? Color(.tertiaryLabel) : .primary)
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

            Spacer().frame(height: 16)

            Button {
                if canSave, let amount = Double(input) {
                    if isAdding {
                        if isIncome { store.addIncome(name: name, amount: amount) }
                        else        { store.addExpense(name: name, amount: amount) }
                    } else if let record {
                        store.updateRecord(id: record.id, isIncome: isIncome, name: name, amount: amount)
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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
