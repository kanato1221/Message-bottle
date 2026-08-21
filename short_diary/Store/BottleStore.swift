//
//  BottleStore.swift
//  short_diary
//

import Combine
import Foundation

@MainActor
final class BottleStore: ObservableObject {
    @Published var bottles: [BottleMessage] = [] {
        didSet {
            save()
        }
    }
    @Published private(set) var reportedBottles: [ReportedBottle] = [] {
        didSet {
            saveReports()
        }
    }
    @Published var exchangeErrorMessage: String?

    private let storageKey = "hitouta.bottles.v1"
    private let reportsStorageKey = "hitouta.reportedBottles.v1"
    private let driftDelay: TimeInterval = 0
    private let exchangeService = BottleExchangeService()
    let isDailyLimitEnabled = true
    let dailyDriftLimit = 5

    init() {
        load()
        loadReports()
    }

    var waitingBottles: [BottleMessage] {
        bottles
            .filter { $0.status == .waiting }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var driftedBottles: [BottleMessage] {
        bottles
            .filter { $0.status == .drifted }
            .sorted { ($0.driftedAt ?? $0.createdAt) > ($1.driftedAt ?? $1.createdAt) }
    }

    var keptBottles: [BottleMessage] {
        bottles
            .filter { $0.status == .kept }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var aloneBottles: [BottleMessage] {
        bottles
            .filter { $0.status == .releasedAlone }
            .sorted { ($0.driftedAt ?? $0.createdAt) > ($1.driftedAt ?? $1.createdAt) }
    }

    var receivedBottles: [ReceivedBottle] {
        driftedBottles.compactMap(\.receivedBottle)
    }

    var todayDriftedCount: Int {
        bottles.filter { bottle in
            guard bottle.status == .drifted, let driftedAt = bottle.driftedAt else { return false }
            return Calendar.current.isDateInToday(driftedAt)
        }.count
    }

    var remainingDriftsToday: Int {
        guard isDailyLimitEnabled else { return dailyDriftLimit }
        return max(dailyDriftLimit - todayDriftedCount, 0)
    }

    var hasWaitingBottle: Bool {
        bottles.contains { $0.status == .waiting }
    }

    var canCreateBottle: Bool {
        !hasWaitingBottle
    }

    var canDriftToday: Bool {
        guard isDailyLimitEnabled else { return true }
        return remainingDriftsToday > 0
    }

    func bottle(text: String, color: BottleColor = .seaGreen) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canCreateBottle else { return }

        let now = Date()
        bottles.append(BottleMessage(
            text: trimmed,
            bottleColor: color,
            createdAt: now,
            availableToDriftAt: now.addingTimeInterval(driftDelay),
            status: .waiting
        ))
    }

    func releaseAlone(_ bottle: BottleMessage) {
        bottles.removeAll { $0.id == bottle.id }
    }

    func drift(_ bottle: BottleMessage, clientID: String) async -> BottleMessage {
        guard let index = bottles.firstIndex(where: { $0.id == bottle.id }) else {
            return bottle
        }

        var updatedBottle = bottles[index]
        guard updatedBottle.status == .waiting, updatedBottle.isReadyToDrift, canDriftToday else {
            return updatedBottle
        }

        do {
            let receivedBottle = try await exchangeService.exchange(bottle: updatedBottle, clientID: clientID)
            updatedBottle.receivedBottle = receivedBottle
            exchangeErrorMessage = nil
        } catch {
            exchangeErrorMessage = "ボトルを流せませんでした。通信状態を確認して、もう一度試してください。"
            return updatedBottle
        }

        updatedBottle.status = .drifted
        updatedBottle.driftedAt = Date()
        bottles[index] = updatedBottle
        return updatedBottle
    }

    func keep(_ bottle: BottleMessage) {
        guard let index = bottles.firstIndex(where: { $0.id == bottle.id }) else { return }
        bottles[index].status = .kept
    }

    func releaseReceived(_ bottle: ReceivedBottle) {
        guard let index = indexOfMessage(containing: bottle) else { return }
        bottles[index].receivedBottle = nil
    }

    func toggleFavorite(for bottle: ReceivedBottle) {
        guard let index = indexOfMessage(containing: bottle),
              var receivedBottle = bottles[index].receivedBottle else { return }
        receivedBottle.isFavorite.toggle()
        bottles[index].receivedBottle = receivedBottle
    }

    func reportReceived(_ bottle: ReceivedBottle) {
        if !reportedBottles.contains(where: { $0.receivedBottleID == bottle.id }) {
            reportedBottles.append(ReportedBottle(
                receivedBottleID: bottle.id,
                serverID: bottle.serverID,
                text: bottle.text,
                reportedAt: Date()
            ))
        }
        releaseReceived(bottle)
    }

    func reportReceived(_ bottle: ReceivedBottle, clientID: String) async {
        do {
            try await exchangeService.report(bottle: bottle, clientID: clientID)
        } catch {
            exchangeErrorMessage = "通報を送信できませんでした。手元の棚からは外しました。"
        }

        reportReceived(bottle)
    }

    func discard(_ bottle: BottleMessage) {
        bottles.removeAll { $0.id == bottle.id }
    }

    func clearLocalData() {
        bottles = []
        reportedBottles = []
        exchangeErrorMessage = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: reportsStorageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([BottleMessage].self, from: data) else {
            bottles = []
            return
        }

        bottles = decoded.map { bottle in
            guard bottle.status == .waiting else { return bottle }
            var updatedBottle = bottle
            updatedBottle.availableToDriftAt = min(bottle.availableToDriftAt, Date())
            return updatedBottle
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bottles) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadReports() {
        guard let data = UserDefaults.standard.data(forKey: reportsStorageKey),
              let decoded = try? JSONDecoder().decode([ReportedBottle].self, from: data) else {
            reportedBottles = []
            return
        }

        reportedBottles = decoded
    }

    private func saveReports() {
        guard let data = try? JSONEncoder().encode(reportedBottles) else { return }
        UserDefaults.standard.set(data, forKey: reportsStorageKey)
    }

    private func indexOfMessage(containing bottle: ReceivedBottle) -> Int? {
        bottles.firstIndex { message in
            guard let receivedBottle = message.receivedBottle else { return false }
            if receivedBottle.id == bottle.id {
                return true
            }
            guard let serverID = bottle.serverID else {
                return false
            }
            return receivedBottle.serverID == serverID
        }
    }
}

enum SampleBottleData {
    static func receivedBottle(for bottle: BottleMessage) -> ReceivedBottle {
        let index = abs(bottle.id.uuidString.hashValue) % samples.count
        let color = BottleColor.allCases[index % BottleColor.allCases.count]
        return ReceivedBottle(text: samples[index], bottleColor: color, driftedAt: Date())
    }

    private static let samples = [
        "知らない駅で降りたら、風だけが先に春でした。",
        "今日は何も進まなかったけど、月だけはちゃんと出ていました。",
        "コンビニの灯りに救われる夜が、たまにあります。",
        "うまく言えなかった言葉を、帰り道で何度も言い直しました。",
        "海を見ていないのに、波の音みたいな日でした。",
        "誰かの小さな親切で、一日が少しだけほどけました。"
    ]
}
