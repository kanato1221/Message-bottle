//
//  ReceivedBottleView.swift
//  short_diary
//

import SwiftUI

struct ReceivedBottleView: View {
    let bottle: ReceivedBottle
    let onKeep: () -> Void
    let onRelease: () -> Void
    let onReport: () -> Void
    @State private var isOpen = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                ZStack {
                    BottleSilhouette()
                        .fill(bottle.bottleColor.gradient)
                        .frame(width: 62, height: 96)
                        .rotationEffect(.degrees(-7))
                        .shadow(color: Color.ink.opacity(0.14), radius: 12, x: 0, y: 8)

                    Image(systemName: "water.waves")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.paper.opacity(0.9))
                        .offset(y: 18)
                }
                .symbolEffect(.bounce, value: isOpen)

                Text("どこかのボトルが、流れ着きました。")
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)

                Text(bottle.text)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(22)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.line)
                    }
                    .opacity(isOpen ? 1 : 0)
                    .offset(y: isOpen ? 0 : 14)

                HStack(spacing: 10) {
                    Button(action: onKeep) {
                        Label("拾っておく", systemImage: "bookmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ReactionButtonStyle(isSelected: true))

                    Button {
                        onRelease()
                    } label: {
                        Label("海に返す", systemImage: "water.waves")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ReactionButtonStyle(isSelected: false))
                }

                Button(role: .destructive, action: onReport) {
                    Label("通報する", systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.cedar.opacity(0.82))
                .padding(.top, 2)

                Spacer()
            }
            .padding(22)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                isOpen = true
            }
        }
    }
}
