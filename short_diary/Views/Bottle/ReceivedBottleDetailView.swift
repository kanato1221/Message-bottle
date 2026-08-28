//
//  ReceivedBottleDetailView.swift
//  short_diary
//

import SwiftUI

struct ReceivedBottleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: BottleStore
    @ObservedObject var authStore: AuthStore
    let bottle: ReceivedBottle
    @State private var isShowingReleaseConfirmation = false
    @State private var isReturningToSea = false
    @State private var isShowingReturnError = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        BottleDetailIcon(color: bottle.bottleColor)
                            .frame(width: 78, height: 112)

                        Text("どこかから流れ着いたボトル")
                            .font(.system(.headline, design: .serif, weight: .semibold))
                            .foregroundStyle(Color.ink)

                        Text(bottle.driftedAt.formatted(.dateTime.year().month().day().weekday(.wide)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Button {
                            store.toggleFavorite(for: currentBottle)
                        } label: {
                            Label(currentBottle.isFavorite ? "お気に入り済み" : "お気に入りにする", systemImage: currentBottle.isFavorite ? "star.fill" : "star")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(currentBottle.isFavorite ? .cedar : .ink)
                    }

                    VStack(spacing: 10) {
                        Text("中に入っていた紙")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        BottleMessagePaper(text: bottle.text)
                    }

                    Button {
                        isShowingReleaseConfirmation = true
                    } label: {
                        Label("海に返す", systemImage: "water.waves")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.cedar)
                    .popover(
                        isPresented: $isShowingReleaseConfirmation,
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .bottom
                    ) {
                        VStack(spacing: 16) {
                            VStack(spacing: 7) {
                                Text("このボトルを海に返しますか？")
                                    .font(.headline)
                                    .foregroundStyle(Color.ink)

                                Text("海に返すと棚から離れ、またどこかの誰かへ流れていきます。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            VStack(spacing: 9) {
                                Button {
                                    returnCurrentBottleToSea()
                                } label: {
                                    Label("海に返す", systemImage: "water.waves")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.cedar)
                                .disabled(isReturningToSea)

                                Button("キャンセル") {
                                    isShowingReleaseConfirmation = false
                                }
                                .buttonStyle(.bordered)
                                .tint(.ink)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(18)
                        .frame(width: 300)
                        .presentationCompactAdaptation(.popover)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 36)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("漂着したボトル")
        .navigationBarTitleDisplayMode(.inline)
        .alert("海に返せませんでした", isPresented: $isShowingReturnError) {
            Button("閉じる", role: .cancel) {}
        } message: {
            Text("通信状態を確認して、もう一度「海に返す」を押してください。ボトルは棚に残っています。")
        }
    }

    private func returnCurrentBottleToSea() {
        guard !isReturningToSea else { return }
        isShowingReleaseConfirmation = false
        isReturningToSea = true

        Task {
            if await store.releaseReceived(currentBottle, clientID: authStore.userID) {
                dismiss()
            } else {
                isReturningToSea = false
                isShowingReturnError = true
            }
        }
    }

    private var currentBottle: ReceivedBottle {
        store.receivedBottles.first { receivedBottle in
            if receivedBottle.id == bottle.id {
                return true
            }
            guard let serverID = bottle.serverID else {
                return false
            }
            return receivedBottle.serverID == serverID
        } ?? bottle
    }
}

private struct BottleMessagePaper: View {
    let text: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppTheme.line)
                }

            VStack(spacing: 18) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(AppTheme.line.opacity(0.22))
                        .frame(height: 1)
                }
            }
            .padding(.horizontal, 18)

            Text(text)
                .font(.system(size: 23, weight: .regular, design: .serif))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(24)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .shadow(color: Color.ink.opacity(0.08), radius: 12, x: 0, y: 7)
    }
}

private struct BottleDetailIcon: View {
    let color: BottleColor

    var body: some View {
        ZStack {
            BottleSilhouette()
                .fill(color.gradient)
                .rotationEffect(.degrees(-6))

            Image(systemName: "paperplane")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.paper.opacity(0.9))
                .offset(y: 14)
        }
        .shadow(color: Color.ink.opacity(0.12), radius: 12, x: 0, y: 8)
    }
}
