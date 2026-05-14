import SwiftUI
import Combine

struct PurchaseItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var amount: Double
    var isBought: Bool = false
    var boughtMonth: Int? = nil
    var boughtYear: Int? = nil
    var boughtDate: Date? = nil
}

struct FinancialRecord: Identifiable, Codable {
    var id = UUID()
    var name: String
    var amount: Double
}

struct Currency: Identifiable {
    let code: String
    let symbol: String
    let name: String
    let flag: String
    var id: String { code }
}

class BudgetStore: ObservableObject {
    @Published var incomeRecords: [FinancialRecord] = []
    @Published var expenseRecords: [FinancialRecord] = []
    @Published var items: [PurchaseItem] = []
    @Published var currentMonth: Int
    @Published var currentYear: Int
    @Published var currencyCode: String

    private let kv = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Currency

    static let supported: [Currency] = [
        Currency(code: "USD", symbol: "$",   name: "US Dollar",         flag: "🇺🇸"),
        Currency(code: "EUR", symbol: "€",   name: "Euro",              flag: "🇪🇺"),
        Currency(code: "GBP", symbol: "£",   name: "British Pound",     flag: "🇬🇧"),
        Currency(code: "JPY", symbol: "¥",   name: "Japanese Yen",      flag: "🇯🇵"),
        Currency(code: "CNY", symbol: "¥",   name: "Chinese Yuan",      flag: "🇨🇳"),
        Currency(code: "CAD", symbol: "$",   name: "Canadian Dollar",   flag: "🇨🇦"),
        Currency(code: "AUD", symbol: "A$",  name: "Australian Dollar", flag: "🇦🇺"),
        Currency(code: "CHF", symbol: "Fr",  name: "Swiss Franc",       flag: "🇨🇭"),
        Currency(code: "INR", symbol: "₹",   name: "Indian Rupee",      flag: "🇮🇳"),
        Currency(code: "BRL", symbol: "R$",  name: "Brazilian Real",    flag: "🇧🇷"),
    ]

    private static func defaultCurrency() -> String {
        let code = Locale.current.currency?.identifier ?? "USD"
        return supported.contains(where: { $0.code == code }) ? code : "USD"
    }

    var currencySymbol: String {
        BudgetStore.supported.first(where: { $0.code == currencyCode })?.symbol ?? currencyCode
    }

    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    func formatAmount(_ amount: Double) -> String {
        formatter.currencyCode   = currencyCode
        formatter.currencySymbol = currencySymbol
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currencySymbol)\(Int(amount))"
    }

    // MARK: - Computed balance

    var totalIncome: Double   { incomeRecords.reduce(0)  { $0 + $1.amount } }
    var totalExpenses: Double { expenseRecords.reduce(0) { $0 + $1.amount } }
    var balance: Double       { totalIncome - totalExpenses }

    // MARK: - Init

    init() {
        let comps = Calendar.current.dateComponents([.month, .year], from: Date())
        currentMonth = comps.month ?? 5
        currentYear  = comps.year  ?? 2026

        kv.synchronize()

        currencyCode = kv.string(forKey: "currencyCode") ?? Self.defaultCurrency()

        if let data = kv.data(forKey: "items"),
           let decoded = try? JSONDecoder().decode([PurchaseItem].self, from: data) {
            items = decoded
        } else {
            items = Self.sampleItems(month: currentMonth, year: currentYear)
            persist()
        }

        if let data = kv.data(forKey: "incomeRecords"),
           let decoded = try? JSONDecoder().decode([FinancialRecord].self, from: data) {
            incomeRecords = decoded
        }
        if let data = kv.data(forKey: "expenseRecords"),
           let decoded = try? JSONDecoder().decode([FinancialRecord].self, from: data) {
            expenseRecords = decoded
        }

        $incomeRecords
            .combineLatest($expenseRecords, $items, $currencyCode)
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.persist() }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kv)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.pull() }
            .store(in: &cancellables)
    }

    // MARK: - iCloud

    private func persist() {
        kv.set(currencyCode, forKey: "currencyCode")
        if let data = try? JSONEncoder().encode(items)          { kv.set(data, forKey: "items") }
        if let data = try? JSONEncoder().encode(incomeRecords)  { kv.set(data, forKey: "incomeRecords") }
        if let data = try? JSONEncoder().encode(expenseRecords) { kv.set(data, forKey: "expenseRecords") }
        kv.synchronize()
    }

    private func pull() {
        if let code = kv.string(forKey: "currencyCode") { currencyCode = code }
        if let data = kv.data(forKey: "items"),
           let decoded = try? JSONDecoder().decode([PurchaseItem].self, from: data) { items = decoded }
        if let data = kv.data(forKey: "incomeRecords"),
           let decoded = try? JSONDecoder().decode([FinancialRecord].self, from: data) { incomeRecords = decoded }
        if let data = kv.data(forKey: "expenseRecords"),
           let decoded = try? JSONDecoder().decode([FinancialRecord].self, from: data) { expenseRecords = decoded }
    }

    // MARK: - Computed

    var boughtInCurrentMonth: [PurchaseItem] {
        items.filter { $0.isBought && $0.boughtMonth == currentMonth && $0.boughtYear == currentYear }
    }

    var plannedItems: [PurchaseItem] {
        items.filter { !$0.isBought }
    }

    var monthSpent: Double {
        boughtInCurrentMonth.reduce(0) { $0 + $1.amount }
    }

    var monthName: String { label(format: "MMMM") }

    var leftDisplay: String {
        let net = balance - monthSpent
        let formatted = formatAmount(abs(net))
        return net < 0 ? "\(formatted) OVER" : "\(formatted) LEFT"
    }

    private func label(format: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = format
        var c = DateComponents(); c.month = currentMonth; c.year = currentYear
        return fmt.string(from: Calendar.current.date(from: c) ?? Date()).uppercased()
    }

    // MARK: - Navigation

    func prevMonth() {
        if currentMonth == 1 { currentMonth = 12; currentYear -= 1 } else { currentMonth -= 1 }
    }

    func nextMonth() {
        if currentMonth == 12 { currentMonth = 1; currentYear += 1 } else { currentMonth += 1 }
    }

    // MARK: - Purchase mutations

    func markBought(id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isBought    = true
        items[i].boughtMonth = currentMonth
        items[i].boughtYear  = currentYear
        items[i].boughtDate  = Date()
    }

    func unmarkBought(id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isBought    = false
        items[i].boughtMonth = nil
        items[i].boughtYear  = nil
        items[i].boughtDate  = nil
    }

    func addItem(name: String, amount: Double) {
        guard amount > 0, amount.isFinite else { return }
        items.append(PurchaseItem(name: name, amount: amount))
    }

    func updateItem(id: UUID, name: String, amount: Double) {
        guard amount > 0, amount.isFinite else { return }
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].name   = name
        items[i].amount = amount
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }

    // MARK: - Financial record mutations

    func addIncome(name: String, amount: Double) {
        guard amount > 0, amount.isFinite else { return }
        incomeRecords.append(FinancialRecord(name: name, amount: amount))
    }

    func addExpense(name: String, amount: Double) {
        guard amount > 0, amount.isFinite else { return }
        expenseRecords.append(FinancialRecord(name: name, amount: amount))
    }

    func updateRecord(id: UUID, isIncome: Bool, name: String, amount: Double) {
        guard amount > 0, amount.isFinite else { return }
        if isIncome {
            guard let i = incomeRecords.firstIndex(where: { $0.id == id }) else { return }
            incomeRecords[i].name = name; incomeRecords[i].amount = amount
        } else {
            guard let i = expenseRecords.firstIndex(where: { $0.id == id }) else { return }
            expenseRecords[i].name = name; expenseRecords[i].amount = amount
        }
    }

    func removeRecord(id: UUID, isIncome: Bool) {
        if isIncome { incomeRecords.removeAll { $0.id == id } }
        else        { expenseRecords.removeAll { $0.id == id } }
    }

    // MARK: - Sample data

    private static func sampleItems(month: Int, year: Int) -> [PurchaseItem] {
        [
            PurchaseItem(name: "Sail shade",     amount: 400, isBought: true, boughtMonth: month, boughtYear: year),
            PurchaseItem(name: "Storage box",    amount: 100),
            PurchaseItem(name: "Garden bench",   amount: 250),
            PurchaseItem(name: "Bird feeder",    amount: 30),
            PurchaseItem(name: "Patio umbrella", amount: 350),
            PurchaseItem(name: "Planter set",    amount: 75),
        ]
    }
}
