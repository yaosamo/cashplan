import SwiftUI

struct SheetHeader: View {
    let title: String
    let onClose: () -> Void
    var onDelete: (() -> Void)? = nil
    var showBack: Bool = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
            HStack {
                Button(action: onClose) {
                    Image(systemName: showBack ? "chevron.left" : "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 42, height: 36)
                        .liquidGlass()
                }
                Spacer()
                if onDelete != nil {
                    Button { showDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 42, height: 36)
                            .liquidGlass()
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .alert("Are you sure?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can't be undone.")
        }
    }
}
