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
    var link: String? = nil
}

enum IncomeCadence: String, CaseIterable, Identifiable, Codable {
    case annual
    case biweekly
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .annual: return "Annual"
        case .biweekly: return "Biweekly"
        case .monthly: return "Monthly"
        }
    }

    var monthlyDivisor: Double {
        switch self {
        case .annual: return 12
        case .biweekly: return 12.0 / 26.0
        case .monthly: return 1
        }
    }
}

struct FinancialRecord: Identifiable, Codable {
    var id = UUID()
    var name: String
    var amount: Double
    var cadence: IncomeCadence = .monthly
    var payday: Date = Date()

    var monthlyAmount: Double {
        amount / cadence.monthlyDivisor
    }

    init(id: UUID = UUID(), name: String, amount: Double, cadence: IncomeCadence = .monthly, payday: Date = Date()) {
        self.id = id
        self.name = name
        self.amount = amount
        self.cadence = cadence
        self.payday = payday
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case amount
        case cadence
        case payday
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(Double.self, forKey: .amount)
        cadence = try container.decodeIfPresent(IncomeCadence.self, forKey: .cadence) ?? .monthly
        payday = try container.decodeIfPresent(Date.self, forKey: .payday) ?? Date()
    }
}

struct MonthlySpend: Identifiable {
    let month: Int
    let year: Int
    let amount: Double
    var id: String { "\(year)-\(String(format: "%02d", month))" }
    var date: Date {
        var c = DateComponents(); c.month = month; c.year = year; c.day = 1
        return Calendar.current.date(from: c) ?? Date()
    }
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
    @Published var monthlyIncomeRecords: [String: [FinancialRecord]] = [:]
    @Published var clearIncomeMonthly: Bool = false
    @Published var expenseRecords: [FinancialRecord] = []
    @Published var items: [PurchaseItem] = []
    @Published var piggyBankAmount: Double = 0
    @Published var currentMonth: Int
    @Published var currentYear: Int
    @Published var currencyCode: String

    private let kv = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Currency

    static let supported: [Currency] = [
        Currency(code: "USD", symbol: "$",    name: "US Dollar",                 flag: "🇺🇸"),
        Currency(code: "EUR", symbol: "€",    name: "Euro",                      flag: "🇪🇺"),
        Currency(code: "GBP", symbol: "£",    name: "British Pound",             flag: "🇬🇧"),
        Currency(code: "JPY", symbol: "¥",    name: "Japanese Yen",              flag: "🇯🇵"),
        Currency(code: "CNY", symbol: "¥",    name: "Chinese Yuan",              flag: "🇨🇳"),
        Currency(code: "CAD", symbol: "$",    name: "Canadian Dollar",           flag: "🇨🇦"),
        Currency(code: "AUD", symbol: "A$",   name: "Australian Dollar",         flag: "🇦🇺"),
        Currency(code: "CHF", symbol: "Fr",   name: "Swiss Franc",               flag: "🇨🇭"),
        Currency(code: "INR", symbol: "₹",    name: "Indian Rupee",              flag: "🇮🇳"),
        Currency(code: "BRL", symbol: "R$",   name: "Brazilian Real",            flag: "🇧🇷"),
        Currency(code: "AED", symbol: "د.إ",  name: "UAE Dirham",                flag: "🇦🇪"),
        Currency(code: "AFN", symbol: "؋",    name: "Afghan Afghani",            flag: "🇦🇫"),
        Currency(code: "ALL", symbol: "L",    name: "Albanian Lek",              flag: "🇦🇱"),
        Currency(code: "AMD", symbol: "֏",    name: "Armenian Dram",             flag: "🇦🇲"),
        Currency(code: "ANG", symbol: "ƒ",    name: "Netherlands Antillean Guilder", flag: "🇨🇼"),
        Currency(code: "AOA", symbol: "Kz",   name: "Angolan Kwanza",            flag: "🇦🇴"),
        Currency(code: "ARS", symbol: "$",    name: "Argentine Peso",            flag: "🇦🇷"),
        Currency(code: "AWG", symbol: "ƒ",    name: "Aruban Florin",             flag: "🇦🇼"),
        Currency(code: "AZN", symbol: "₼",    name: "Azerbaijani Manat",         flag: "🇦🇿"),
        Currency(code: "BAM", symbol: "KM",   name: "Bosnia-Herzegovina Mark",   flag: "🇧🇦"),
        Currency(code: "BBD", symbol: "$",    name: "Barbadian Dollar",          flag: "🇧🇧"),
        Currency(code: "BDT", symbol: "৳",    name: "Bangladeshi Taka",          flag: "🇧🇩"),
        Currency(code: "BGN", symbol: "лв",   name: "Bulgarian Lev",             flag: "🇧🇬"),
        Currency(code: "BHD", symbol: "BD",   name: "Bahraini Dinar",            flag: "🇧🇭"),
        Currency(code: "BIF", symbol: "FBu",  name: "Burundian Franc",           flag: "🇧🇮"),
        Currency(code: "BMD", symbol: "$",    name: "Bermudian Dollar",          flag: "🇧🇲"),
        Currency(code: "BND", symbol: "$",    name: "Brunei Dollar",             flag: "🇧🇳"),
        Currency(code: "BOB", symbol: "Bs",   name: "Bolivian Boliviano",        flag: "🇧🇴"),
        Currency(code: "BSD", symbol: "$",    name: "Bahamian Dollar",           flag: "🇧🇸"),
        Currency(code: "BTN", symbol: "Nu.",  name: "Bhutanese Ngultrum",        flag: "🇧🇹"),
        Currency(code: "BWP", symbol: "P",    name: "Botswana Pula",             flag: "🇧🇼"),
        Currency(code: "BZD", symbol: "$",    name: "Belize Dollar",             flag: "🇧🇿"),
        Currency(code: "BYN", symbol: "Br",   name: "Belarusian Ruble",          flag: "🇧🇾"),
        Currency(code: "CDF", symbol: "FC",   name: "Congolese Franc",           flag: "🇨🇩"),
        Currency(code: "CLP", symbol: "$",    name: "Chilean Peso",              flag: "🇨🇱"),
        Currency(code: "COP", symbol: "$",    name: "Colombian Peso",            flag: "🇨🇴"),
        Currency(code: "CRC", symbol: "₡",    name: "Costa Rican Colon",         flag: "🇨🇷"),
        Currency(code: "CUP", symbol: "$",    name: "Cuban Peso",                flag: "🇨🇺"),
        Currency(code: "CVE", symbol: "$",    name: "Cape Verdean Escudo",       flag: "🇨🇻"),
        Currency(code: "CZK", symbol: "Kč",   name: "Czech Koruna",              flag: "🇨🇿"),
        Currency(code: "DJF", symbol: "Fdj",  name: "Djiboutian Franc",          flag: "🇩🇯"),
        Currency(code: "DKK", symbol: "kr",   name: "Danish Krone",              flag: "🇩🇰"),
        Currency(code: "DOP", symbol: "$",    name: "Dominican Peso",            flag: "🇩🇴"),
        Currency(code: "DZD", symbol: "دج",   name: "Algerian Dinar",            flag: "🇩🇿"),
        Currency(code: "EGP", symbol: "E£",   name: "Egyptian Pound",            flag: "🇪🇬"),
        Currency(code: "ERN", symbol: "Nfk",  name: "Eritrean Nakfa",            flag: "🇪🇷"),
        Currency(code: "ETB", symbol: "Br",   name: "Ethiopian Birr",            flag: "🇪🇹"),
        Currency(code: "FJD", symbol: "$",    name: "Fijian Dollar",             flag: "🇫🇯"),
        Currency(code: "GEL", symbol: "₾",    name: "Georgian Lari",             flag: "🇬🇪"),
        Currency(code: "GHS", symbol: "₵",    name: "Ghanaian Cedi",             flag: "🇬🇭"),
        Currency(code: "GIP", symbol: "£",    name: "Gibraltar Pound",           flag: "🇬🇮"),
        Currency(code: "GMD", symbol: "D",    name: "Gambian Dalasi",            flag: "🇬🇲"),
        Currency(code: "GNF", symbol: "FG",   name: "Guinean Franc",             flag: "🇬🇳"),
        Currency(code: "GTQ", symbol: "Q",    name: "Guatemalan Quetzal",        flag: "🇬🇹"),
        Currency(code: "GYD", symbol: "$",    name: "Guyanese Dollar",           flag: "🇬🇾"),
        Currency(code: "HKD", symbol: "HK$",  name: "Hong Kong Dollar",          flag: "🇭🇰"),
        Currency(code: "HNL", symbol: "L",    name: "Honduran Lempira",          flag: "🇭🇳"),
        Currency(code: "HTG", symbol: "G",    name: "Haitian Gourde",            flag: "🇭🇹"),
        Currency(code: "HUF", symbol: "Ft",   name: "Hungarian Forint",          flag: "🇭🇺"),
        Currency(code: "IDR", symbol: "Rp",   name: "Indonesian Rupiah",         flag: "🇮🇩"),
        Currency(code: "ILS", symbol: "₪",    name: "Israeli Shekel",            flag: "🇮🇱"),
        Currency(code: "IQD", symbol: "ع.د",  name: "Iraqi Dinar",               flag: "🇮🇶"),
        Currency(code: "IRR", symbol: "﷼",    name: "Iranian Rial",              flag: "🇮🇷"),
        Currency(code: "ISK", symbol: "kr",   name: "Icelandic Krona",           flag: "🇮🇸"),
        Currency(code: "JMD", symbol: "$",    name: "Jamaican Dollar",           flag: "🇯🇲"),
        Currency(code: "JOD", symbol: "JD",   name: "Jordanian Dinar",           flag: "🇯🇴"),
        Currency(code: "KES", symbol: "KSh",  name: "Kenyan Shilling",           flag: "🇰🇪"),
        Currency(code: "KGS", symbol: "с",    name: "Kyrgyzstani Som",           flag: "🇰🇬"),
        Currency(code: "KHR", symbol: "៛",    name: "Cambodian Riel",            flag: "🇰🇭"),
        Currency(code: "KMF", symbol: "CF",   name: "Comorian Franc",            flag: "🇰🇲"),
        Currency(code: "KRW", symbol: "₩",    name: "South Korean Won",          flag: "🇰🇷"),
        Currency(code: "KWD", symbol: "KD",   name: "Kuwaiti Dinar",             flag: "🇰🇼"),
        Currency(code: "KYD", symbol: "$",    name: "Cayman Islands Dollar",     flag: "🇰🇾"),
        Currency(code: "KZT", symbol: "₸",    name: "Kazakhstani Tenge",         flag: "🇰🇿"),
        Currency(code: "LAK", symbol: "₭",    name: "Lao Kip",                   flag: "🇱🇦"),
        Currency(code: "LBP", symbol: "ل.ل",  name: "Lebanese Pound",            flag: "🇱🇧"),
        Currency(code: "LKR", symbol: "Rs",   name: "Sri Lankan Rupee",          flag: "🇱🇰"),
        Currency(code: "LRD", symbol: "$",    name: "Liberian Dollar",           flag: "🇱🇷"),
        Currency(code: "LSL", symbol: "L",    name: "Lesotho Loti",              flag: "🇱🇸"),
        Currency(code: "LYD", symbol: "LD",   name: "Libyan Dinar",              flag: "🇱🇾"),
        Currency(code: "MAD", symbol: "DH",   name: "Moroccan Dirham",           flag: "🇲🇦"),
        Currency(code: "MDL", symbol: "L",    name: "Moldovan Leu",              flag: "🇲🇩"),
        Currency(code: "MGA", symbol: "Ar",   name: "Malagasy Ariary",           flag: "🇲🇬"),
        Currency(code: "MKD", symbol: "ден",  name: "Macedonian Denar",          flag: "🇲🇰"),
        Currency(code: "MMK", symbol: "K",    name: "Myanmar Kyat",              flag: "🇲🇲"),
        Currency(code: "MNT", symbol: "₮",    name: "Mongolian Tugrik",          flag: "🇲🇳"),
        Currency(code: "MOP", symbol: "MOP$", name: "Macanese Pataca",           flag: "🇲🇴"),
        Currency(code: "MRU", symbol: "UM",   name: "Mauritanian Ouguiya",       flag: "🇲🇷"),
        Currency(code: "MUR", symbol: "₨",    name: "Mauritian Rupee",           flag: "🇲🇺"),
        Currency(code: "MVR", symbol: "Rf",   name: "Maldivian Rufiyaa",         flag: "🇲🇻"),
        Currency(code: "MWK", symbol: "MK",   name: "Malawian Kwacha",           flag: "🇲🇼"),
        Currency(code: "MXN", symbol: "$",    name: "Mexican Peso",              flag: "🇲🇽"),
        Currency(code: "MYR", symbol: "RM",   name: "Malaysian Ringgit",         flag: "🇲🇾"),
        Currency(code: "MZN", symbol: "MT",   name: "Mozambican Metical",        flag: "🇲🇿"),
        Currency(code: "NAD", symbol: "$",    name: "Namibian Dollar",           flag: "🇳🇦"),
        Currency(code: "NGN", symbol: "₦",    name: "Nigerian Naira",            flag: "🇳🇬"),
        Currency(code: "NIO", symbol: "C$",   name: "Nicaraguan Cordoba",        flag: "🇳🇮"),
        Currency(code: "NOK", symbol: "kr",   name: "Norwegian Krone",           flag: "🇳🇴"),
        Currency(code: "NPR", symbol: "₨",    name: "Nepalese Rupee",            flag: "🇳🇵"),
        Currency(code: "NZD", symbol: "NZ$",  name: "New Zealand Dollar",        flag: "🇳🇿"),
        Currency(code: "OMR", symbol: "OMR",  name: "Omani Rial",                flag: "🇴🇲"),
        Currency(code: "PAB", symbol: "B/.",  name: "Panamanian Balboa",         flag: "🇵🇦"),
        Currency(code: "PEN", symbol: "S/",   name: "Peruvian Sol",              flag: "🇵🇪"),
        Currency(code: "PGK", symbol: "K",    name: "Papua New Guinean Kina",    flag: "🇵🇬"),
        Currency(code: "PHP", symbol: "₱",    name: "Philippine Peso",           flag: "🇵🇭"),
        Currency(code: "PKR", symbol: "₨",    name: "Pakistani Rupee",           flag: "🇵🇰"),
        Currency(code: "PLN", symbol: "zł",   name: "Polish Zloty",              flag: "🇵🇱"),
        Currency(code: "PYG", symbol: "₲",    name: "Paraguayan Guarani",        flag: "🇵🇾"),
        Currency(code: "QAR", symbol: "QR",   name: "Qatari Riyal",              flag: "🇶🇦"),
        Currency(code: "RON", symbol: "Lei",  name: "Romanian Leu",              flag: "🇷🇴"),
        Currency(code: "RSD", symbol: "дин",  name: "Serbian Dinar",             flag: "🇷🇸"),
        Currency(code: "RWF", symbol: "RF",   name: "Rwandan Franc",             flag: "🇷🇼"),
        Currency(code: "SAR", symbol: "SR",   name: "Saudi Riyal",               flag: "🇸🇦"),
        Currency(code: "SBD", symbol: "$",    name: "Solomon Islands Dollar",    flag: "🇸🇧"),
        Currency(code: "SCR", symbol: "₨",    name: "Seychellois Rupee",         flag: "🇸🇨"),
        Currency(code: "SDG", symbol: "SDG",  name: "Sudanese Pound",            flag: "🇸🇩"),
        Currency(code: "SEK", symbol: "kr",   name: "Swedish Krona",             flag: "🇸🇪"),
        Currency(code: "SGD", symbol: "S$",   name: "Singapore Dollar",          flag: "🇸🇬"),
        Currency(code: "SHP", symbol: "£",    name: "Saint Helena Pound",        flag: "🇸🇭"),
        Currency(code: "SLE", symbol: "Le",   name: "Sierra Leonean Leone",      flag: "🇸🇱"),
        Currency(code: "SOS", symbol: "Sh",   name: "Somali Shilling",           flag: "🇸🇴"),
        Currency(code: "SRD", symbol: "$",    name: "Surinamese Dollar",         flag: "🇸🇷"),
        Currency(code: "SSP", symbol: "£",    name: "South Sudanese Pound",      flag: "🇸🇸"),
        Currency(code: "STN", symbol: "Db",   name: "Sao Tome and Principe Dobra", flag: "🇸🇹"),
        Currency(code: "SYP", symbol: "£",    name: "Syrian Pound",              flag: "🇸🇾"),
        Currency(code: "SZL", symbol: "E",    name: "Swazi Lilangeni",           flag: "🇸🇿"),
        Currency(code: "THB", symbol: "฿",    name: "Thai Baht",                 flag: "🇹🇭"),
        Currency(code: "TJS", symbol: "SM",   name: "Tajikistani Somoni",        flag: "🇹🇯"),
        Currency(code: "TMT", symbol: "m",    name: "Turkmenistani Manat",       flag: "🇹🇲"),
        Currency(code: "TND", symbol: "DT",   name: "Tunisian Dinar",            flag: "🇹🇳"),
        Currency(code: "TOP", symbol: "T$",   name: "Tongan Paanga",             flag: "🇹🇴"),
        Currency(code: "TRY", symbol: "₺",    name: "Turkish Lira",              flag: "🇹🇷"),
        Currency(code: "TTD", symbol: "$",    name: "Trinidad and Tobago Dollar", flag: "🇹🇹"),
        Currency(code: "TWD", symbol: "NT$",  name: "Taiwan Dollar",             flag: "🇹🇼"),
        Currency(code: "TZS", symbol: "TSh",  name: "Tanzanian Shilling",        flag: "🇹🇿"),
        Currency(code: "UAH", symbol: "₴",    name: "Ukrainian Hryvnia",         flag: "🇺🇦"),
        Currency(code: "UGX", symbol: "USh",  name: "Ugandan Shilling",          flag: "🇺🇬"),
        Currency(code: "UYU", symbol: "$",    name: "Uruguayan Peso",            flag: "🇺🇾"),
        Currency(code: "UZS", symbol: "soʻm", name: "Uzbekistani Som",           flag: "🇺🇿"),
        Currency(code: "VES", symbol: "Bs",   name: "Venezuelan Bolivar",        flag: "🇻🇪"),
        Currency(code: "VND", symbol: "₫",    name: "Vietnamese Dong",           flag: "🇻🇳"),
        Currency(code: "VUV", symbol: "VT",   name: "Vanuatu Vatu",              flag: "🇻🇺"),
        Currency(code: "WST", symbol: "T",    name: "Samoan Tala",               flag: "🇼🇸"),
        Currency(code: "XAF", symbol: "FCFA", name: "Central African CFA Franc", flag: "🇨🇲"),
        Currency(code: "XCD", symbol: "$",    name: "East Caribbean Dollar",     flag: "🇦🇬"),
        Currency(code: "XOF", symbol: "CFA",  name: "West African CFA Franc",    flag: "🇸🇳"),
        Currency(code: "XPF", symbol: "F",    name: "CFP Franc",                 flag: "🇵🇫"),
        Currency(code: "YER", symbol: "﷼",    name: "Yemeni Rial",               flag: "🇾🇪"),
        Currency(code: "ZAR", symbol: "R",    name: "South African Rand",        flag: "🇿🇦"),
        Currency(code: "ZMW", symbol: "ZK",   name: "Zambian Kwacha",            flag: "🇿🇲"),
        Currency(code: "ZWL", symbol: "Z$",   name: "Zimbabwean Dollar",         flag: "🇿🇼"),
    ]

    private static func defaultCurrency() -> String {
        let code = Locale.current.currency?.identifier ?? "USD"
        return supported.contains(where: { $0.code == code }) ? code : "USD"
    }

    var currencySymbol: String {
        selectedCurrency?.symbol ?? currencyCode
    }

    private var selectedCurrency: Currency? {
        BudgetStore.supported.first(where: { $0.code == currencyCode })
    }

    private var symbolFollowsAmount: Bool {
        Self.trailingSymbolCurrencyCodes.contains(currencyCode)
    }

    private static let trailingSymbolCurrencyCodes: Set<String> = [
        "AED", "AFN", "ALL", "AMD", "AOA", "BAM", "BGN", "BHD", "BIF", "BYN",
        "CDF", "CHF", "CVE", "CZK", "DJF", "DKK", "DZD", "ERN", "ETB", "EUR",
        "GEL", "GMD", "GNF", "HUF", "IQD", "IRR", "ISK", "JOD", "KES", "KGS",
        "KMF", "KWD", "KZT", "LBP", "MAD", "MDL", "MGA", "MKD", "MMK", "MNT",
        "MRU", "MVR", "MWK", "MZN", "NOK", "OMR", "PLN", "QAR", "RON", "RSD",
        "RWF", "SAR", "SDG", "SEK", "SLE", "SOS", "SYP", "SZL", "TJS", "TMT",
        "TND", "UGX", "UZS", "VND", "XAF", "XOF", "XPF", "YER", "ZMW"
    ]

    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    func formatAmount(_ amount: Double) -> String {
        let sign = amount < 0 ? "-" : ""
        let number = formatter.string(from: NSNumber(value: abs(amount))) ?? "\(Int(abs(amount)))"
        return sign + formatCurrencyNumber(number)
    }

    func formatBalanceAmount(_ amount: Double) -> String {
        let absoluteAmount = abs(amount)
        guard absoluteAmount >= 10_000 else { return formatAmount(amount) }

        let sign = amount < 0 ? "-" : ""
        let compactValue = absoluteAmount / 1_000
        let number = compactValue >= 100
            ? String(format: "%.0fk", compactValue)
            : String(format: "%.1fk", compactValue).replacingOccurrences(of: ".0k", with: "k")

        return sign + formatCurrencyNumber(number)
    }

    func formatCurrencyInput(_ input: String) -> String {
        formatCurrencyNumber(numpadDisplay(input))
    }

    func formatCurrencyNumber(_ number: String) -> String {
        if symbolFollowsAmount {
            return "\(number) \(currencySymbol)"
        }
        return "\(currencySymbol)\(number)"
    }

    // MARK: - Computed balance

    var currentMonthKey: String { "\(currentYear)-\(String(format: "%02d", currentMonth))" }

    var activeIncomeRecords: [FinancialRecord] {
        clearIncomeMonthly ? monthlyIncomeRecords[currentMonthKey, default: []] : incomeRecords
    }

    var totalIncome: Double        { activeIncomeRecords.reduce(0) { $0 + $1.monthlyAmount } }
    var totalExpenses: Double      { expenseRecords.reduce(0) { $0 + $1.amount } }
    var totalBalance: Double       { totalIncome - totalExpenses }
    var balance: Double            { totalBalance - piggyBankAmount }

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
        piggyBankAmount = max(0, kv.double(forKey: "piggyBankAmount"))
        clearIncomeMonthly = kv.bool(forKey: "clearIncomeMonthly")
        if let data = kv.data(forKey: "monthlyIncomeRecords"),
           let decoded = try? JSONDecoder().decode([String: [FinancialRecord]].self, from: data) {
            monthlyIncomeRecords = decoded
        }

        $incomeRecords
            .combineLatest($expenseRecords, $items, $currencyCode)
            .combineLatest($piggyBankAmount, $monthlyIncomeRecords, $clearIncomeMonthly)
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
        kv.set(clearIncomeMonthly, forKey: "clearIncomeMonthly")
        kv.set(piggyBankAmount, forKey: "piggyBankAmount")
        if let data = try? JSONEncoder().encode(items)                 { kv.set(data, forKey: "items") }
        if let data = try? JSONEncoder().encode(incomeRecords)         { kv.set(data, forKey: "incomeRecords") }
        if let data = try? JSONEncoder().encode(expenseRecords)        { kv.set(data, forKey: "expenseRecords") }
        if let data = try? JSONEncoder().encode(monthlyIncomeRecords)  { kv.set(data, forKey: "monthlyIncomeRecords") }
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
        piggyBankAmount = max(0, kv.double(forKey: "piggyBankAmount"))
        clearIncomeMonthly = kv.bool(forKey: "clearIncomeMonthly")
        if let data = kv.data(forKey: "monthlyIncomeRecords"),
           let decoded = try? JSONDecoder().decode([String: [FinancialRecord]].self, from: data) { monthlyIncomeRecords = decoded }
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

    var canDepositToPiggyBank: Bool {
        balance - monthSpent >= 1
    }

    var monthlySpendHistory: [MonthlySpend] {
        Dictionary(
            grouping: items.filter { $0.isBought && $0.boughtMonth != nil && $0.boughtYear != nil },
            by: { "\($0.boughtYear!)-\(String(format: "%02d", $0.boughtMonth!))" }
        )
        .map { _, group in
            MonthlySpend(month: group[0].boughtMonth!, year: group[0].boughtYear!,
                         amount: group.reduce(0) { $0 + $1.amount })
        }
        .sorted { $0.year != $1.year ? $0.year < $1.year : $0.month < $1.month }
    }

    var monthName: String { label(format: "MMMM") }

    var daysInCurrentMonth: Int {
        var dc = DateComponents(); dc.month = currentMonth; dc.year = currentYear
        guard let anchor = Calendar.current.date(from: dc),
              let range  = Calendar.current.range(of: .day, in: .month, for: anchor) else { return 31 }
        return range.count
    }

    var monthProgress: Double {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.month, .year], from: now)
        let thisMonth = comps.month ?? currentMonth
        let thisYear  = comps.year  ?? currentYear
        if currentYear < thisYear  || (currentYear == thisYear && currentMonth < thisMonth) { return 1.0 }
        if currentYear > thisYear  || (currentYear == thisYear && currentMonth > thisMonth) { return 0.0 }
        return Double(cal.component(.day, from: now)) / Double(daysInCurrentMonth)
    }

    var salaryPaydaysInCurrentMonth: Set<Int> {
        let cal = Calendar.current
        var monthComponents = DateComponents()
        monthComponents.year = currentYear
        monthComponents.month = currentMonth
        monthComponents.day = 1

        guard let monthStart = cal.date(from: monthComponents),
              let monthRange = cal.range(of: .day, in: .month, for: monthStart),
              let monthEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return []
        }

        var days = Set<Int>()

        for record in activeIncomeRecords {
            switch record.cadence {
            case .monthly:
                let selectedDay = cal.component(.day, from: record.payday)
                days.insert(min(selectedDay, monthRange.count))
            case .annual:
                let paydayComponents = cal.dateComponents([.month, .day], from: record.payday)
                guard paydayComponents.month == currentMonth, let day = paydayComponents.day else { continue }
                days.insert(min(day, monthRange.count))
            case .biweekly:
                let paydayStart = cal.startOfDay(for: record.payday)
                guard paydayStart <= monthEnd else { continue }
                let daySpan = cal.dateComponents([.day], from: paydayStart, to: monthStart).day ?? 0
                let periodsBeforeMonth = max(0, Int(floor(Double(daySpan) / 14.0)))
                guard var occurrence = cal.date(byAdding: .day, value: periodsBeforeMonth * 14, to: paydayStart) else { continue }

                while occurrence < monthStart {
                    guard let next = cal.date(byAdding: .day, value: 14, to: occurrence) else { break }
                    occurrence = next
                }

                while occurrence <= monthEnd {
                    let components = cal.dateComponents([.year, .month, .day], from: occurrence)
                    if components.year == currentYear, components.month == currentMonth, let day = components.day {
                        days.insert(day)
                    }
                    guard let next = cal.date(byAdding: .day, value: 14, to: occurrence) else { break }
                    occurrence = next
                }
            }
        }

        return days
    }

    var isOver: Bool { balance - monthSpent < 0 }

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

    func addItem(name: String, amount: Double, link: String = "") {
        guard amount > 0, amount.isFinite else { return }
        var item = PurchaseItem(name: name, amount: amount)
        item.link = link.isEmpty ? nil : link
        items.append(item)
    }

    func updateItem(id: UUID, name: String, amount: Double, link: String = "", boughtDate: Date? = nil) {
        guard amount > 0, amount.isFinite else { return }
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].name   = name
        items[i].amount = amount
        items[i].link   = link.isEmpty ? nil : link

        if items[i].isBought, let boughtDate {
            let components = Calendar.current.dateComponents([.month, .year], from: boughtDate)
            items[i].boughtDate = boughtDate
            items[i].boughtMonth = components.month
            items[i].boughtYear = components.year
        }
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }

    // MARK: - Piggy bank mutations

    @discardableResult
    func depositToPiggyBank(amount: Double = 1) -> Bool {
        guard amount > 0, amount.isFinite, balance - monthSpent >= amount else { return false }
        piggyBankAmount += amount
        return true
    }

    func updatePiggyBank(amount: Double) {
        guard amount.isFinite else { return }
        piggyBankAmount = max(0, amount)
    }

    func smashPiggyBank() {
        piggyBankAmount = 0
    }

    // MARK: - Financial record mutations

    func addIncome(name: String, amount: Double, cadence: IncomeCadence = .monthly, payday: Date = Date()) {
        guard amount > 0, amount.isFinite else { return }
        if clearIncomeMonthly {
            var records = monthlyIncomeRecords[currentMonthKey, default: []]
            records.append(FinancialRecord(name: name, amount: amount, cadence: cadence, payday: payday))
            monthlyIncomeRecords[currentMonthKey] = records
        } else {
            incomeRecords.append(FinancialRecord(name: name, amount: amount, cadence: cadence, payday: payday))
        }
    }

    func addExpense(name: String, amount: Double) {
        guard amount > 0, amount.isFinite else { return }
        expenseRecords.append(FinancialRecord(name: name, amount: amount))
    }

    func updateRecord(id: UUID, isIncome: Bool, name: String, amount: Double, cadence: IncomeCadence = .monthly, payday: Date = Date()) {
        guard amount > 0, amount.isFinite else { return }
        if isIncome {
            if clearIncomeMonthly {
                var records = monthlyIncomeRecords[currentMonthKey, default: []]
                guard let i = records.firstIndex(where: { $0.id == id }) else { return }
                records[i].name = name; records[i].amount = amount; records[i].cadence = cadence; records[i].payday = payday
                monthlyIncomeRecords[currentMonthKey] = records
            } else {
                guard let i = incomeRecords.firstIndex(where: { $0.id == id }) else { return }
                incomeRecords[i].name = name; incomeRecords[i].amount = amount; incomeRecords[i].cadence = cadence; incomeRecords[i].payday = payday
            }
        } else {
            guard let i = expenseRecords.firstIndex(where: { $0.id == id }) else { return }
            expenseRecords[i].name = name; expenseRecords[i].amount = amount
        }
    }

    func removeRecord(id: UUID, isIncome: Bool) {
        if isIncome {
            if clearIncomeMonthly {
                var records = monthlyIncomeRecords[currentMonthKey, default: []]
                records.removeAll { $0.id == id }
                monthlyIncomeRecords[currentMonthKey] = records
            } else {
                incomeRecords.removeAll { $0.id == id }
            }
        } else {
            expenseRecords.removeAll { $0.id == id }
        }
    }

    // MARK: - Sample data

    private static func sampleItems(month: Int, year: Int) -> [PurchaseItem] {
        [
            PurchaseItem(name: "Standing desk",      amount: 649),
            PurchaseItem(name: "Mechanical keyboard", amount: 189),
            PurchaseItem(name: "Monitor light bar",  amount: 55),
            PurchaseItem(name: "Wireless charger",   amount: 39),
            PurchaseItem(name: "Desk organiser",     amount: 45),
            PurchaseItem(name: "Noise cancelling headphones", amount: 299),
            PurchaseItem(name: "Laptop stand",       amount: 79),
            PurchaseItem(name: "Webcam",             amount: 129),
            PurchaseItem(name: "Cable management kit", amount: 22),
            PurchaseItem(name: "Desk plant",         amount: 18),
        ]
    }
}
