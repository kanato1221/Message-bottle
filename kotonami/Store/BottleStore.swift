//
//  BottleStore.swift
//  kotonami
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
    private let dailyDriftCountResetKey = "hitouta.dailyDriftCountReset.v3"

    let isDailyLimitEnabled = true

    private let exchangeService = BottleExchangeService()
    private let cloudStore = BottleCloudStore()
    private let notificationScheduler = BottleReadyNotificationScheduler.shared
    private var currentUserID: String?
    private var isApplyingCloudState = false
    private var dailyDriftCountResetAt = Date.distantPast
    let dailyDriftLimit = 5

    init() {
        if let savedResetAt = UserDefaults.standard.object(forKey: dailyDriftCountResetKey) as? Date {
            dailyDriftCountResetAt = savedResetAt
        } else {
            let resetAt = Date()
            dailyDriftCountResetAt = resetAt
            UserDefaults.standard.set(resetAt, forKey: dailyDriftCountResetKey)
        }
        load()
        loadReports()
        notificationScheduler.cancelAllReadyNotifications()
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

    var receivedBottles: [ReceivedBottle] {
        driftedBottles.compactMap(\.receivedBottle)
    }

    var todayDriftedCount: Int {
        bottles.filter { bottle in
            guard bottle.status == .drifted, let driftedAt = bottle.driftedAt else { return false }
            return driftedAt >= dailyDriftCountResetAt && Calendar.current.isDateInToday(driftedAt)
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

    func isReadyToDrift(_ bottle: BottleMessage) -> Bool {
        bottle.status == .waiting
    }

    @discardableResult
    func bottle(text: String, color: BottleColor = .seaGreen) -> BottleMessage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canCreateBottle else { return nil }

        let now = Date()
        let bottle = BottleMessage(
            text: trimmed,
            bottleColor: color,
            createdAt: now,
            availableToDriftAt: now,
            status: .waiting
        )

        bottles.append(bottle)
        return bottle
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

    func hold(_ bottle: BottleMessage) {
        notificationScheduler.scheduleHoldReminder(for: bottle)
    }

    func drift(_ bottle: BottleMessage, clientID: String) async -> BottleMessage {
        guard let index = bottles.firstIndex(where: { $0.id == bottle.id }) else {
            return bottle
        }

        var updatedBottle = bottles[index]
        guard isReadyToDrift(updatedBottle), canDriftToday else {
            return updatedBottle
        }

        do {
            let result = try await exchangeService.exchange(bottle: updatedBottle, clientID: clientID)
            updatedBottle.serverID = result.sentBottleServerID
            updatedBottle.receivedBottle = result.receivedBottle
            exchangeErrorMessage = nil
        } catch BottleExchangeError.unsafeContent {
            exchangeErrorMessage = "この内容は安全上の理由により流せません。個人情報や不適切な表現が含まれていないか確認してください。"
            return updatedBottle
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

    func releaseReceived(_ bottle: ReceivedBottle, clientID: String) async -> Bool {
        do {
            try await exchangeService.returnToSea(bottle, clientID: clientID)
            removeReceived(bottle)
            exchangeErrorMessage = nil
            return true
        } catch {
            exchangeErrorMessage = "ボトルを海に返せませんでした。通信状態を確認して、もう一度試してください。"
            return false
        }
    }

    private func removeReceived(_ bottle: ReceivedBottle) {
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
        removeReceived(bottle)
    }

    func reportReceived(_ bottle: ReceivedBottle, clientID: String) async -> Bool {
        do {
            try await exchangeService.report(bottle: bottle, clientID: clientID)
            reportReceived(bottle)
            exchangeErrorMessage = nil
            return true
        } catch {
            exchangeErrorMessage = "通報を送信できませんでした。通信状態を確認して、もう一度試してください。"
            return false
        }
    }

    func blockSender(of bottle: ReceivedBottle, clientID: String) async -> Bool {
        do {
            try await exchangeService.blockSender(of: bottle, clientID: clientID)
            removeReceived(bottle)
            exchangeErrorMessage = nil
            return true
        } catch {
            exchangeErrorMessage = "ブロックを送信できませんでした。通信状態を確認して、もう一度試してください。"
            return false
        }
    }

    func discard(_ bottle: BottleMessage) {
        notificationScheduler.cancelReadyNotification(for: bottle.id)
        bottles.removeAll { $0.id == bottle.id }
    }

    func deleteSentBottle(_ bottle: BottleMessage) async -> Bool {
        do {
            try await exchangeService.deleteSentBottle(bottle)
            discard(bottle)
            exchangeErrorMessage = nil
            return true
        } catch {
            exchangeErrorMessage = "投稿を削除できませんでした。通信状態を確認して、もう一度試してください。"
            return false
        }
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
