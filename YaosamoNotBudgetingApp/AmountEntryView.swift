import SwiftUI

// MARK: - Money Input Helpers

enum MoneyInput {
    static func editableString(_ amount: Double) -> String {
        guard amount.truncatingRemainder(dividingBy: 1) != 0 else { return String(Int(amount)) }
        var s = String(format: "%.2f", amount)
        while s.hasSuffix("0") { s = String(s.dropLast()) }
        return s
    }

    static func appendDigit(_ digit: String, to input: inout String) {
        guard input.count < 10 else { return }
        if digit == "0" && input.isEmpty { return }
        if input.contains(".") {
            let decimals = input.components(separatedBy: ".")[1]
            if decimals.count >= 2 { return }
        }
        input += digit
    }

    static func appendDecimal(to input: inout String) {
        guard !input.contains(".") else { return }
        input += input.isEmpty ? "0." : "."
    }

    static func deleteLast(from input: inout String) {
        guard !input.isEmpty else { return }
        input.removeLast()
    }
}

func numpadDisplay(_ input: String) -> String {
    let s = input.isEmpty ? "0" : input
    let parts = s.components(separatedBy: ".")
    var result = ""
    for (i, c) in parts[0].reversed().enumerated() {
        if i > 0 && i % 3 == 0 { result = "," + result }
        result = String(c) + result
    }
    return parts.count > 1 ? result + "." + parts[1] : result
}

// MARK: - Amount Display

struct AmountDisplayText: View {
    let input: String
    let currencySymbol: String

    var body: some View {
        Text("\(currencySymbol)\(numpadDisplay(input))")
            .font(.system(size: 72, weight: .medium, design: .rounded))
            .foregroundColor(.primary)
            .minimumScaleFactor(0.3)
            .lineLimit(1)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: input)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Numpad

struct NumpadView: View {
    @Binding var input: String

    var body: some View {
        VStack(spacing: 10) {
            ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { n in
                        numKey("\(n)") { MoneyInput.appendDigit("\(n)", to: &input) }
                    }
                }
            }
            HStack(spacing: 10) {
                numKey(".") { MoneyInput.appendDecimal(to: &input) }
                numKey("0") { MoneyInput.appendDigit("0", to: &input) }
                numKey("⌫") { MoneyInput.deleteLast(from: &input) }
            }
        }
    }

    @ViewBuilder
    private func numKey(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: label == "⌫" ? 20 : 26, weight: .regular))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(Color(.secondarySystemBackground)).cornerRadius(12)
        }
    }
}

// MARK: - Amount Entry Sheet

struct AmountEntrySheet: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @Binding var input: String

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Amount", onClose: { dismiss() }, onConfirm: { dismiss() })
            AmountDisplayText(input: input, currencySymbol: store.currencySymbol)
                .frame(maxHeight: .infinity)
            NumpadView(input: $input).padding(.horizontal, 16)
            Spacer().frame(height: 36)
        }
    }
}
