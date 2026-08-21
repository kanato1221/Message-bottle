//
//  ReceivedBottleDetailView.swift
//  short_diary
//

import SwiftUI

struct ReceivedBottleDetailView: View {
    @ObservedObject var store: BottleStore
    let bottle: ReceivedBottle

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
                }
                .padding(.horizontal, 22)
                .padding(.top, 36)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("漂着したボトル")
        .navigationBarTitleDisplayMode(.inline)
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
