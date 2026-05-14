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
                    .foregroundStyle(.white, green)
                    .font(.system(size: 28, weight: .light))
                    .shadow(color: green.opacity(0.55), radius: 6)
                    .shadow(color: green.opacity(0.25), radius: 14)
                    .symbolEffect(.bounce, value: bounce)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 17)).foregroundColor(.primary)
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
        .onLongPressGesture { onEdit() }
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
            Image(systemName: "circle")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(Color(.tertiaryLabel))
                .symbolEffect(.bounce, value: bounce)
            Text(item.name).font(.system(size: 17)).foregroundColor(.primary)
            Spacer()
            Text(store.formatAmount(item.amount)).font(.system(size: 17)).foregroundColor(.primary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            bounce.toggle()
            withAnimation(.spring(response: 0.35)) { store.markBought(id: item.id) }
        }
        .onLongPressGesture { onEdit() }
    }
}

// MARK: - Sheet Header

struct SheetHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(.secondaryLabel))
                        .frame(width: 28, height: 28)
                        .background(Color(.systemFill))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}
