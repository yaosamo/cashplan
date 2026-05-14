import SwiftUI

// MARK: - Add Purchase Sheet

struct AddPurchaseSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var amountText = ""
    @FocusState private var focused: Bool

    var canSave: Bool {
        guard let amount = Double(amountText) else { return false }
        return !name.isEmpty && amount > 0 && amount.isFinite
    }

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
                if let amount = Double(amountText), amount > 0, amount.isFinite, !name.isEmpty {
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
                    if let amount = Double(amountText), amount > 0, amount.isFinite, !name.isEmpty {
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
