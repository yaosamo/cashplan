import SwiftUI

// MARK: - Bought Row

struct BoughtRowView: View {
    @EnvironmentObject var store: BudgetStore
    let item: PurchaseItem
    let onEdit: () -> Void
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 16) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                bounce.toggle()
                withAnimation(.spring(response: 0.35)) { store.unmarkBought(id: item.id) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, AppColors.success)
                    .font(.system(size: 28, weight: .light))
                    .shadow(color: AppColors.success.opacity(0.55), radius: 6)
                    .shadow(color: AppColors.success.opacity(0.25), radius: 14)
                    .symbolEffect(.bounce, value: bounce)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.name).font(.system(size: 17)).foregroundColor(.primary)
                    if item.link != nil {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
                if let date = item.boughtDate {
                    Text(date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text("-\(store.formatAmount(item.amount))").font(.system(size: 17)).foregroundColor(.primary)
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}

// MARK: - Planned Row

struct PlannedRowView: View {
    @EnvironmentObject var store: BudgetStore
    let item: PurchaseItem
    let onEdit: () -> Void
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 16) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                bounce.toggle()
                withAnimation(.spring(response: 0.35)) { store.markBought(id: item.id) }
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(Color(.tertiaryLabel))
                    .symbolEffect(.bounce, value: bounce)
            }
            HStack(spacing: 5) {
                Text(item.name).font(.system(size: 17)).foregroundColor(.primary)
                if item.link != nil {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            Spacer()
            Text(store.formatAmount(item.amount)).font(.system(size: 17)).foregroundColor(.primary)
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}

