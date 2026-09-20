//
//  BottleShelfView.swift
//  kotonami
//

import SwiftUI

struct BottleShelfView: View {
    @ObservedObject var store: BottleStore
    @ObservedObject var authStore: AuthStore
    @State private var selectedMode = 0
    @State private var receivedSort = ReceivedBottleSort.newest

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    Picker("表示", selection: $selectedMode) {
                        Label("漂着", systemImage: "sparkles").tag(0)
                        Label("流した", systemImage: "water.waves").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    ScrollView {
                        if selectedMode == 0 {
                            receivedShelfContent
                        } else {
                            sentShelfContent
                        }
                    }
                }
            }
            .navigationTitle("ボトル棚")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedMode == 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ForEach(ReceivedBottleSort.allCases) { sort in
                                Button {
                                    receivedSort = sort
                                } label: {
                                    Label(sort.title, systemImage: receivedSort == sort ? "checkmark" : sort.iconName)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.ink)
                        }
                        .accessibilityLabel("並び替え")
                    }
                }
            }
        }
    }

    private var receivedShelfContent: some View {
        LazyVStack(spacing: 22) {
            ForEach(Array(receivedShelves.enumerated()), id: \.offset) { _, shelf in
                BottleShelfRow(store: store, authStore: authStore, bottles: shelf)
            }

            if store.receivedBottles.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: emptyIcon)
                    .padding(.top, 80)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 28)
    }

    private var sentShelfContent: some View {
        LazyVStack(spacing: 22) {
            ForEach(Array(sentShelves.enumerated()), id: \.offset) { _, shelf in
                SentBottleShelfRow(store: store, bottles: shelf)
            }

            if store.driftedBottles.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: emptyIcon)
                    .padding(.top, 80)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 28)
    }

    private var receivedShelves: [[ReceivedBottle]] {
        let bottles = sortedReceivedBottles
        return stride(from: 0, to: bottles.count, by: 3).map { index in
            Array(bottles[index..<min(index + 3, bottles.count)])
        }
    }

    private var sentShelves: [[BottleMessage]] {
        let bottles = store.driftedBottles
        return stride(from: 0, to: bottles.count, by: 3).map { index in
            Array(bottles[index..<min(index + 3, bottles.count)])
        }
    }

    private var sortedReceivedBottles: [ReceivedBottle] {
        switch receivedSort {
        case .newest:
            return store.receivedBottles.sorted { $0.driftedAt > $1.driftedAt }
        case .oldest:
            return store.receivedBottles.sorted { $0.driftedAt < $1.driftedAt }
        case .favorite:
            return store.receivedBottles.sorted {
                if $0.isFavorite != $1.isFavorite {
                    return $0.isFavorite && !$1.isFavorite
                }
                return $0.driftedAt > $1.driftedAt
            }
        }
    }

    private var emptyTitle: String {
        switch selectedMode {
        case 0: "まだボトルは漂着していません"
        case 1: "まだ海へ流していません"
        default: "ボトルはありません"
        }
    }

    private var emptyIcon: String {
        switch selectedMode {
        case 0: "sparkles"
        case 1: "water.waves"
        default: "shippingbox"
        }
    }
}

private enum ReceivedBottleSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case favorite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "新しい順"
        case .oldest: "古い順"
        case .favorite: "お気に入り"
        }
    }

    var iconName: String {
        switch self {
        case .newest: "arrow.down"
        case .oldest: "arrow.up"
        case .favorite: "star"
        }
    }
}

private struct BottleShelfRow: View {
    @ObservedObject var store: BottleStore
    @ObservedObject var authStore: AuthStore
    let bottles: [ReceivedBottle]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 18) {
                ForEach(bottles) { bottle in
                    NavigationLink {
                        ReceivedBottleDetailView(store: store, authStore: authStore, bottle: bottle)
                    } label: {
                        ShelfBottleView(bottle: bottle)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }

                ForEach(0..<max(0, 3 - bottles.count), id: \.self) { _ in
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 118)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.paper.opacity(0.62))
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 50)
                    }
            }

            ShelfBoard()
                .frame(height: 28)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.line.opacity(0.7))
        }
        .shadow(color: Color.ink.opacity(0.08), radius: 12, x: 0, y: 7)
    }
}

private struct SentBottleShelfRow: View {
    @ObservedObject var store: BottleStore
    let bottles: [BottleMessage]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 18) {
                ForEach(bottles) { bottle in
                    NavigationLink {
                        SentBottleDetailView(store: store, bottle: bottle)
                    } label: {
                        SentShelfBottleView(bottle: bottle)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }

                ForEach(0..<max(0, 3 - bottles.count), id: \.self) { _ in
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 118)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.paper.opacity(0.62))
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 50)
                    }
            }

            ShelfBoard()
                .frame(height: 28)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.line.opacity(0.7))
        }
        .shadow(color: Color.ink.opacity(0.08), radius: 12, x: 0, y: 7)
    }
}

private struct SentShelfBottleView: View {
    let bottle: BottleMessage

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                BottleSilhouette()
                    .fill(bottle.bottleColor.gradient)
                    .overlay {
                        BottleSilhouette()
                            .stroke(Color.paper.opacity(0.54), lineWidth: 1.4)
                    }
                    .frame(width: 48, height: 86)
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: Color.ink.opacity(0.11), radius: 7, x: 0, y: 5)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 23, height: 30)
                    .rotationEffect(.degrees(rotation + 5))
                    .offset(y: 14)

                Capsule()
                    .fill(Color.cedar.opacity(0.48))
                    .frame(width: 22, height: 7)
                    .offset(y: -37)
                    .rotationEffect(.degrees(rotation))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 98)

            Text(sentDate.formatted(.dateTime.month().day()))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("流したボトル、\(sentDate.formatted(.dateTime.month().day()))")
    }

    private var sentDate: Date { bottle.driftedAt ?? bottle.createdAt }

    private var rotation: Double {
        let value = abs(bottle.id.uuidString.hashValue % 7)
        return Double(value - 3)
    }
}

private struct ShelfBottleView: View {
    let bottle: ReceivedBottle

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                BottleSilhouette()
                    .fill(bottle.bottleColor.gradient)
                    .overlay {
                        BottleSilhouette()
                            .stroke(Color.paper.opacity(0.54), lineWidth: 1.4)
                    }
                    .frame(width: 48, height: 86)
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: Color.ink.opacity(0.11), radius: 7, x: 0, y: 5)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 23, height: 30)
                    .rotationEffect(.degrees(rotation + 5))
                    .offset(y: 14)

                Capsule()
                    .fill(Color.cedar.opacity(0.48))
                    .frame(width: 22, height: 7)
                    .offset(y: -37)
                    .rotationEffect(.degrees(rotation))

                if bottle.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.cedar)
                        .padding(5)
                        .background(Color.paper.opacity(0.86), in: Circle())
                        .offset(x: 25, y: -33)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 98)

            Text(bottle.driftedAt.formatted(.dateTime.month().day()))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("漂着したボトル、\(bottle.driftedAt.formatted(.dateTime.month().day()))")
    }

    private var rotation: Double {
        let value = abs(bottle.id.uuidString.hashValue % 7)
        return Double(value - 3)
    }
}

private struct ShelfBoard: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.60, green: 0.43, blue: 0.30),
                            Color(red: 0.42, green: 0.29, blue: 0.20)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 2)

            HStack(spacing: 18) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(Color.ink.opacity(index.isMultiple(of: 2) ? 0.13 : 0.08))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 11)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ink.opacity(0.16))
                .frame(height: 6)
                .blur(radius: 3)
                .offset(y: 4)
        }
    }
}

struct BottleSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let neckWidth = width * 0.34
        let neckLeft = (width - neckWidth) / 2
        let neckRight = neckLeft + neckWidth
        let shoulderY = height * 0.28

        var path = Path()
        path.move(to: CGPoint(x: neckLeft, y: height * 0.05))
        path.addLine(to: CGPoint(x: neckRight, y: height * 0.05))
        path.addLine(to: CGPoint(x: neckRight, y: shoulderY))
        path.addCurve(
            to: CGPoint(x: width * 0.9, y: height * 0.46),
            control1: CGPoint(x: width * 0.62, y: height * 0.32),
            control2: CGPoint(x: width * 0.82, y: height * 0.34)
        )
        path.addLine(to: CGPoint(x: width * 0.9, y: height * 0.88))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.1, y: height * 0.88),
            control: CGPoint(x: width * 0.5, y: height * 1.02)
        )
        path.addLine(to: CGPoint(x: width * 0.1, y: height * 0.46))
        path.addCurve(
            to: CGPoint(x: neckLeft, y: shoulderY),
            control1: CGPoint(x: width * 0.18, y: height * 0.34),
            control2: CGPoint(x: width * 0.38, y: height * 0.32)
        )
        path.closeSubpath()

        return path
    }
}
