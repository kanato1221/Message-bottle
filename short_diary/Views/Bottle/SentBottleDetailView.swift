import SwiftUI

struct SentBottleDetailView: View {
    let bottle: BottleMessage

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
                }
                .padding(.horizontal, 22)
                .padding(.top, 36)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("流したボトル")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sentDate: Date { bottle.driftedAt ?? bottle.createdAt }
}
