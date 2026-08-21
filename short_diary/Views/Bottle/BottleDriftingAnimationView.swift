//
//  BottleDriftingAnimationView.swift
//  short_diary
//

import SwiftUI

struct BottleDriftingAnimationView: View {
    let bottleColor: BottleColor
    @State private var isDrifting = false
    @State private var isFloating = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.94, blue: 0.90),
                    Color(red: 0.78, green: 0.88, blue: 0.89),
                    Color(red: 0.43, green: 0.65, blue: 0.68)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                let size = proxy.size

                ZStack {
                    VStack(spacing: 18) {
                        Spacer()

                        Text("ボトルを流しています")
                            .font(.system(.headline, design: .serif, weight: .semibold))
                            .foregroundStyle(Color.ink)

                        Text("知らない誰かの海へ向かっています。")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, size.height * 0.18)

                    DriftingWaveLine()
                        .stroke(Color.paper.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(height: 28)
                        .offset(y: size.height * 0.60)

                    DriftingWaveLine()
                        .stroke(Color.moss.opacity(0.42), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(height: 28)
                        .offset(y: size.height * 0.66)

                    DriftingBottle(color: bottleColor)
                        .frame(width: 82, height: 120)
                        .rotationEffect(.degrees(isFloating ? 9 : -7))
                        .offset(
                            x: isDrifting ? size.width * 0.36 : -size.width * 0.34,
                            y: isFloating ? size.height * 0.05 : size.height * 0.08
                        )
                        .animation(.easeInOut(duration: 2.0), value: isDrifting)
                        .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: isFloating)
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .onAppear {
            isFloating = true
            withAnimation(.easeInOut(duration: 2.0)) {
                isDrifting = true
            }
        }
        .allowsHitTesting(true)
    }
}

private struct DriftingBottle: View {
    let color: BottleColor

    var body: some View {
        ZStack {
            BottleSilhouette()
                .fill(color.gradient)
                .overlay {
                    BottleSilhouette()
                        .stroke(Color.paper.opacity(0.72), lineWidth: 1.6)
                }

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.paper.opacity(0.86))
                .frame(width: 34, height: 42)
                .rotationEffect(.degrees(8))
                .offset(y: 18)

            Capsule()
                .fill(Color.cedar.opacity(0.62))
                .frame(width: 31, height: 9)
                .offset(y: -51)
        }
        .shadow(color: Color.ink.opacity(0.16), radius: 14, x: 0, y: 10)
    }
}

private struct DriftingWaveLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = rect.width / 8
        let amplitude = rect.height * 0.28
        let midY = rect.midY

        path.move(to: CGPoint(x: -step, y: midY))

        for index in 0...10 {
            let x = CGFloat(index) * step - step
            let nextX = x + step
            let controlX = x + step / 2
            let y = midY + (index.isMultiple(of: 2) ? amplitude : -amplitude)
            let nextY = midY + (index.isMultiple(of: 2) ? -amplitude : amplitude)

            path.addCurve(
                to: CGPoint(x: nextX, y: nextY),
                control1: CGPoint(x: controlX, y: y),
                control2: CGPoint(x: controlX, y: nextY)
            )
        }

        return path
    }
}
