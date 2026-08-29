//
//  BottleReadyNotificationScheduler.swift
//  short_diary
//

import Foundation
import UserNotifications

final class BottleReadyNotificationScheduler {
    static let shared = BottleReadyNotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "bottle-ready-"

    private init() {}

    func scheduleReadyNotification(for bottle: BottleMessage) {
        guard bottle.status == .waiting else { return }

        let delay = bottle.availableToDriftAt.timeIntervalSinceNow
        guard delay > 0 else { return }

        Task {
            let granted = await requestAuthorizationIfNeeded()
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "ボトルを海に流せるようになりました"
            content.body = "さっき入れた言葉を、誰かの海へ流せます。"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
            let request = UNNotificationRequest(
                identifier: identifier(for: bottle.id),
                content: content,
                trigger: trigger
            )

            center.removePendingNotificationRequests(withIdentifiers: [identifier(for: bottle.id)])

            do {
                try await center.add(request)
            } catch {
                // 通知予約に失敗しても、ボトル作成そのものは止めない。
            }
        }
    }

    func scheduleHoldReminder(for bottle: BottleMessage) {
        guard bottle.status == .waiting else { return }

        Task {
            let granted = await requestAuthorizationIfNeeded()
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "保留中のボトルがあります"
            content.body = "さっき保留した言葉を、海へ流すか確認してみませんか。"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifier(for: bottle.id),
                content: content,
                trigger: trigger
            )

            center.removePendingNotificationRequests(withIdentifiers: [identifier(for: bottle.id)])

            do {
                try await center.add(request)
            } catch {
                // 通知予約に失敗しても、ボトルの保留そのものは止めない。
            }
        }
    }

    func cancelReadyNotification(for bottleID: UUID) {
        let notificationID = identifier(for: bottleID)
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        center.removeDeliveredNotifications(withIdentifiers: [notificationID])
    }

    func cancelAllReadyNotifications() {
        Task {
            let requests = await center.pendingNotificationRequests()
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func identifier(for bottleID: UUID) -> String {
        identifierPrefix + bottleID.uuidString
    }
}
