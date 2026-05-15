import SwiftUI
import Charts

struct AnalyticsSheet: View {
    @EnvironmentObject var store: BudgetStore
    @Environment(\.dismiss) private var dismiss

    private var allData: [MonthlySpend] { store.monthlySpendHistory }
    private var chartData: [MonthlySpend] {
        let year = Calendar.current.component(.year, from: Date())
        return (1...12).map { month in
            let amount = allData.first { $0.month == month && $0.year == year }?.amount ?? 0
            return MonthlySpend(month: month, year: year, amount: amount)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Color.clear.frame(height: 72)

                    if allData.isEmpty {
                        VStack(spacing: 8) {
                            Text("No spending data yet.")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            Text("Mark items as bought to see your history here.")
                                .font(.system(size: 13))
                                .foregroundColor(Color(.tertiaryLabel))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        chartSection
                        monthRows
                    }
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

            SheetHeader(title: "Analytics") { dismiss() }
        }
        .background(Color(.secondarySystemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartSection: some View {
        Chart {
            ForEach(chartData) { point in
                BarMark(
                    x: .value("Month", point.date, unit: .month),
                    y: .value("Spent", point.amount),
                    width: .fixed(10)
                )
                .foregroundStyle(
                    point.amount > store.balance && store.balance > 0
                        ? Color.primary.opacity(0.9)
                        : AppColors.success.opacity(0.8)
                )
                .cornerRadius(3)
            }

            if store.balance > 0 {
                RuleMark(y: .value("Budget", store.balance))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .foregroundStyle(Color(red: 0xEC/255, green: 0x5E/255, blue: 0x2D/255))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.system(size: 10, design: .monospaced))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(store.formatAmount(v))
                            .font(.system(size: 9, design: .monospaced))
                    }
                }
            }
        }
        .frame(height: 220)
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(14)
    }

    // MARK: - Month rows

    @ViewBuilder
    private var monthRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(allData.reversed().enumerated()), id: \.element.id) { idx, point in
                    let over = store.balance > 0 ? max(0, point.amount - store.balance) : 0
                    let isOver = over > 0

                    HStack(alignment: .center) {
                        Text(monthLabel(point))
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(store.formatAmount(point.amount))
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            if isOver {
                                Text("\(store.formatAmount(over)) over")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if idx < allData.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(14)
        }
    }

    private func monthLabel(_ point: MonthlySpend) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: point.date)
    }
}
