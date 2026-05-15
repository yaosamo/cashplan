import SwiftUI

// MARK: - Edit / Add Item Sheet

struct EditItemSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss

    let item: PurchaseItem?
    @State private var input: String
    @State private var name: String
    @State private var showAmountSheet = false
    @State private var link: String
    @FocusState private var nameFocused: Bool

    init(item: PurchaseItem? = nil) {
        self.item = item
        _input = State(initialValue: item.map { MoneyInput.editableString($0.amount) } ?? "")
        _name  = State(initialValue: item?.name ?? "")
        _link  = State(initialValue: item?.link ?? "")
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

            TextField("Purchase", text: $name)
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

            HStack {
                Text("Link")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                Spacer()
                if link.isEmpty {
                    Button("Paste") { link = UIPasteboard.general.string ?? "" }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    TextField("https://", text: $link)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Button { link = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .padding(.horizontal, 16)

            Spacer().frame(height: 16)

            Button {
                if canSave, let amount = Double(input) {
                    if isAdding {
                        store.addItem(name: name, amount: amount, link: link)
                    } else if let item {
                        store.updateItem(id: item.id, name: name, amount: amount, link: link)
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
        }
    }
}
