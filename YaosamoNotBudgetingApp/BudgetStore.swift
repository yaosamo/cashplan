import SwiftUI
import Combine

struct PurchaseItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var amount: Double
    var isBought: Bool = false
    var boughtMonth: Int? = nil
    var boughtYear: Int? = nil
}

class BudgetStore: ObservableObject {
    @Published var balance: Double = 0
    @Published var items: [PurchaseItem] = []
    @Published var currentMonth: Int
    @Published var currentYear: Int

    private let kv = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()

    init() {
        let comps = Calendar.current.dateComponents([.month, .year], from: Date())
        currentMonth = comps.month ?? 5
        currentYear  = comps.year  ?? 2026

        kv.synchronize()

        // Load from iCloud; seed sample data on first launch
        balance = kv.double(forKey: "balance")
        if let data = kv.data(forKey: "items"),
           let decoded = try? JSONDecoder().decode([PurchaseItem].self, from: data) {
            items = decoded
        } else {
            items = Self.sampleItems(month: currentMonth, year: currentYear)
            persist()
        }

        // Auto-save 500ms after any change (dropFirst skips the init emissions)
        $balance
            .combineLatest($items)
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.persist() }
            .store(in: &cancellables)

        // Pull changes pushed from another device
        NotificationCenter.default
            .publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kv)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.pull() }
            .store(in: &cancellables)
    }

    // MARK: - iCloud

    private func persist() {
        kv.set(balance, forKey: "balance")
        if let data = try? JSONEncoder().encode(items) {
            kv.set(data, forKey: "items")
        }
        kv.synchronize()
    }

    private func pull() {
        let newBalance = kv.double(forKey: "balance")
        guard let data = kv.data(forKey: "items"),
              let decoded = try? JSONDecoder().decode([PurchaseItem].self, from: data) else { return }
        balance = newBalance
        items   = decoded
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

    var netDisplay: String {
        let net = balance - monthSpent
        let abs = Swift.abs(net)
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 0
        let s = fmt.string(from: NSNumber(value: abs)) ?? "0"
        return net < 0 ? "-$\(s)" : "$\(s)"
    }

    var monthName: String {
        label(format: "MMMM")
    }

    var monthYearLabel: String {
        label(format: "MMMM, yyyy")
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

    // MARK: - Mutations

    func markBought(id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isBought    = true
        items[i].boughtMonth = currentMonth
        items[i].boughtYear  = currentYear
    }

    func unmarkBought(id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isBought    = false
        items[i].boughtMonth = nil
        items[i].boughtYear  = nil
    }

    func addItem(name: String, amount: Double) {
        items.append(PurchaseItem(name: name, amount: amount))
    }

    func updateItem(id: UUID, name: String, amount: Double) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].name   = name
        items[i].amount = amount
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
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
