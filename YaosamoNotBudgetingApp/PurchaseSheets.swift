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
    @State private var purchaseDate: Date
    @State private var showPurchaseDatePicker = false
    @State private var showInvalidLinkAlert = false
    @FocusState private var nameFocused: Bool

    init(item: PurchaseItem? = nil) {
        self.item = item
        _input = State(initialValue: item.map { MoneyInput.editableString($0.amount) } ?? "")
        _name  = State(initialValue: item?.name ?? "")
        _link  = State(initialValue: item?.link ?? "")
        _purchaseDate = State(initialValue: Self.initialPurchaseDate(for: item))
    }

    private var isAdding: Bool { item == nil }
    private var isBoughtItem: Bool { item?.isBought == true }

    private var hasRequiredFields: Bool {
        guard let amount = Double(input) else { return false }
        return amount > 0 && amount.isFinite && !name.isEmpty
    }

    private var normalizedLink: String? { PurchaseLink.normalized(link)?.absoluteString }
    private var linkIsValid: Bool { link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || normalizedLink != nil }

    private static func initialPurchaseDate(for item: PurchaseItem?) -> Date {
        if let date = item?.boughtDate { return date }
        if let month = item?.boughtMonth, let year = item?.boughtYear {
            var components = DateComponents()
            components.month = month
            components.year = year
            components.day = 1
            return Calendar.current.date(from: components) ?? Date()
        }
        return Date()
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
            .padding(.bottom, 10)

            if isBoughtItem {
                Button { showPurchaseDatePicker = true } label: {
                    HStack {
                        Text("Purchased")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(purchaseDate.formatted(.dateTime.month(.abbreviated).day().year()))
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
                .padding(.bottom, 10)
            }

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
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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
                if !hasRequiredFields {
                    showAmountSheet = true
                } else if !linkIsValid {
                    showInvalidLinkAlert = true
                } else if let amount = Double(input) {
                    if isAdding {
                        store.addItem(name: name, amount: amount, link: normalizedLink ?? "")
                    } else if let item {
                        store.updateItem(id: item.id, name: name, amount: amount, link: normalizedLink ?? "", boughtDate: isBoughtItem ? purchaseDate : nil)
                    }
                    dismiss()
                }
            } label: {
                Text(hasRequiredFields ? (isAdding ? "Add" : "Save") : "Next")
                    .font(.headline)
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Color(.label))
                    .cornerRadius(14)
                    .animation(.easeInOut(duration: 0.15), value: hasRequiredFields)
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
        .sheet(isPresented: $showPurchaseDatePicker) {
            PurchaseDatePickerSheet(date: $purchaseDate)
                .presentationDetents([.fraction(0.68)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .alert("Invalid link", isPresented: $showInvalidLinkAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Enter a valid website URL, like example.com or https://example.com.")
        }
    }
}

struct PurchaseDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var date: Date

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Purchased") { dismiss() }

            DatePicker("Purchased", selection: $date, displayedComponents: [.date])
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
