import SwiftUI
import SafariServices

enum PurchaseLink {
    static func normalized(_ rawValue: String?) -> URL? {
        let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }

        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: withScheme),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              host.contains("."),
              let url = components.url else {
            return nil
        }

        return url
    }
}

private struct SafariURL: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}

// MARK: - Bought Row

struct BoughtRowView: View {
    @EnvironmentObject var store: BudgetStore
    let item: PurchaseItem
    let onEdit: () -> Void
    @State private var bounce = false
    @State private var safariURL: SafariURL?

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
                    if let url = PurchaseLink.normalized(item.link) {
                        Button {
                            safariURL = SafariURL(url: url)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
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
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Planned Row

struct PlannedRowView: View {
    @EnvironmentObject var store: BudgetStore
    let item: PurchaseItem
    let onEdit: () -> Void
    @State private var bounce = false
    @State private var safariURL: SafariURL?

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
                if let url = PurchaseLink.normalized(item.link) {
                    Button {
                        safariURL = SafariURL(url: url)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            Text(store.formatAmount(item.amount)).font(.system(size: 17)).foregroundColor(.primary)
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }
}
