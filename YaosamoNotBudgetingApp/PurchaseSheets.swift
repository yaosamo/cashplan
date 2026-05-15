import SwiftUI

// MARK: - Edit / Add Item Sheet

struct EditItemSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss

    let item: PurchaseItem?
    @State private var input: String
    @State private var name: String
    @FocusState private var nameFocused: Bool

    init(item: PurchaseItem? = nil) {
        self.item = item
        _input = State(initialValue: item.map { MoneyInput.editableString($0.amount) } ?? "")
        _name  = State(initialValue: item?.name ?? "")
    }

    private var isAdding: Bool { item == nil }

    var canSave: Bool {
        guard let amount = Double(input) else { return false }
        return amount > 0 && amount.isFinite && !name.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: isAdding ? "Plan Purchase" : "Edit",
                onClose: { dismiss() },
                onDelete: isAdding ? nil : {
                    if let item { store.removeItem(id: item.id) }
                    dismiss()
                }
            )

            Spacer()

            AmountDisplayText(input: input, currencySymbol: store.currencySymbol)

            Spacer()

            HStack {
                Text("Name")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                Spacer()
                TextField("–", text: $name)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.trailing)
                    .focused($nameFocused)
                    .foregroundColor(.primary)
                    .submitLabel(.done)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .padding(.horizontal, 16)

            Spacer().frame(height: 16)

            Button {
                guard let amount = Double(input), amount > 0, amount.isFinite, !name.isEmpty else { return }
                if isAdding {
                    store.addItem(name: name, amount: amount)
                } else if let item {
                    store.updateItem(id: item.id, name: name, amount: amount)
                }
                dismiss()
            } label: {
                Text(isAdding ? "Add" : "Save")
                    .font(.headline)
                    .foregroundColor(canSave ? Color(.systemBackground) : .secondary)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(canSave ? Color(.label) : Color(.tertiarySystemFill))
                    .cornerRadius(14)
                    .animation(.easeInOut(duration: 0.15), value: canSave)
            }
            .disabled(!canSave)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            if !nameFocused {
                NumpadView(input: $input).padding(.horizontal, 16)
                Spacer().frame(height: 36)
            }
        }
    }
}
