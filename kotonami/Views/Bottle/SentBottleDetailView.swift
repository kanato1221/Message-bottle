import SwiftUI

struct SentBottleDetailView: View {
    @ObservedObject var store: BottleStore
    let bottle: BottleMessage
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteResultMessage: String?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        BottleDetailIcon(color: bottle.bottleColor)
                            .frame(width: 78, height: 112)

                        Text("自分が海へ流したボトル")
                            .font(.system(.headline, design: .serif, weight: .semibold))
                            .foregroundStyle(Color.ink)

                        Text(sentDate.formatted(.dateTime.year().month().day().weekday(.wide)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 10) {
                        Text("中に入れた紙")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        BottleMessagePaper(text: bottle.text)
                    }

                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label("この投稿を削除", systemImage: "trash")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.cedar)
                    .disabled(isDeleting)
                }
                .padding(.horizontal, 22)
                .padding(.top, 36)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("流したボトル")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "この投稿を一覧から削除しますか？",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                isDeleting = true
                Task {
                    let didDelete = await store.deleteSentBottle(bottle)
                    isDeleting = false
                    deleteResultMessage = didDelete
                        ? "Firebase上の投稿を削除しました。すでに誰かに届いているボトルは、その人のボトル棚に残ります。"
                        : "投稿を削除できませんでした。通信状態を確認して、もう一度試してください。"
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("Firebase上の投稿と自分の「流した」一覧から削除されます。すでに誰かに届いたボトルは削除されません。")
        }
        .alert("削除結果", isPresented: Binding(
            get: { deleteResultMessage != nil },
            set: { if !$0 { deleteResultMessage = nil } }
        )) {
            Button("OK") {
                if !store.bottles.contains(where: { $0.id == bottle.id }) {
                    dismiss()
                }
            }
        } message: {
            Text(deleteResultMessage ?? "")
        }
    }

    private var sentDate: Date { bottle.driftedAt ?? bottle.createdAt }
}
