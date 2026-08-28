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
    private let accountStorageKey = "hitouta.bottles.accountUserID.v1"
    private let reportsStorageKey = "hitouta.reportedBottles.v1"
    private let driftDelay: TimeInterval = 60 * 60
    private let exchangeService = BottleExchangeService()
    private let cloudStore = BottleCloudStore()
    private let notificationScheduler = BottleReadyNotificationScheduler.shared
    private var currentUserID: String?
    private var isApplyingCloudState = false
    let isDailyLimitEnabled = true
    let dailyDriftLimit = 5

    init() {
        load()
        loadReports()
        rescheduleWaitingBottleNotifications()
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
        let bottle = BottleMessage(
            text: trimmed,
            bottleColor: color,
            createdAt: now,
            availableToDriftAt: now.addingTimeInterval(driftDelay),
            status: .waiting
        )

        bottles.append(bottle)
        notificationScheduler.scheduleReadyNotification(for: bottle)
    }

    func connectAccount(userID: String) async {
        guard currentUserID != userID else { return }

        let previousUserID = UserDefaults.standard.string(forKey: accountStorageKey)
        if let previousUserID, previousUserID != userID {
            isApplyingCloudState = true
            bottles = []
            isApplyingCloudState = false
        }

        currentUserID = userID
        UserDefaults.standard.set(userID, forKey: accountStorageKey)

        do {
            if let cloudBottles = try await cloudStore.loadBottles(for: userID) {
                isApplyingCloudState = true
                bottles = mergedBottles(local: bottles, cloud: cloudBottles)
                isApplyingCloudState = false
            }

            saveToCloud()
            rescheduleWaitingBottleNotifications()
        } catch {
            exchangeErrorMessage = "ボトル棚を同期できませんでした。通信状態を確認してください。"
        }
    }

    func disconnectAccount() {
        currentUserID = nil
    }

    func releaseAlone(_ bottle: BottleMessage) {
        notificationScheduler.cancelReadyNotification(for: bottle.id)
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
        notificationScheduler.cancelReadyNotification(for: updatedBottle.id)
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

    func blockSender(of bottle: ReceivedBottle, clientID: String) async {
        do {
            try await exchangeService.blockSender(of: bottle, clientID: clientID)
            exchangeErrorMessage = nil
        } catch {
            exchangeErrorMessage = "ブロックを送信できませんでした。手元の棚からは外しました。"
        }

        releaseReceived(bottle)
    }

    func discard(_ bottle: BottleMessage) {
        notificationScheduler.cancelReadyNotification(for: bottle.id)
        bottles.removeAll { $0.id == bottle.id }
    }

    func clearLocalData() {
        notificationScheduler.cancelAllReadyNotifications()
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

        bottles = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bottles) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        saveToCloud()
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

    private func rescheduleWaitingBottleNotifications() {
        waitingBottles.forEach { bottle in
            notificationScheduler.scheduleReadyNotification(for: bottle)
        }
    }

    private func saveToCloud() {
        guard !isApplyingCloudState, let currentUserID else { return }

        let bottles = bottles
        let cloudStore = cloudStore
        Task {
            do {
                try await cloudStore.saveBottles(bottles, for: currentUserID)
            } catch {
                await MainActor.run {
                    exchangeErrorMessage = "ボトル棚を同期できませんでした。通信状態を確認してください。"
                }
            }
        }
    }

    private func mergedBottles(local: [BottleMessage], cloud: [BottleMessage]) -> [BottleMessage] {
        var merged = Dictionary(uniqueKeysWithValues: cloud.map { ($0.id, $0) })

        for bottle in local {
            if let cloudBottle = merged[bottle.id] {
                merged[bottle.id] = newerBottle(bottle, cloudBottle)
            } else {
                merged[bottle.id] = bottle
            }
        }

        return merged.values.sorted { $0.createdAt > $1.createdAt }
    }

    private func newerBottle(_ first: BottleMessage, _ second: BottleMessage) -> BottleMessage {
        let firstDate = first.driftedAt ?? first.createdAt
        let secondDate = second.driftedAt ?? second.createdAt
        return firstDate >= secondDate ? first : second
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
