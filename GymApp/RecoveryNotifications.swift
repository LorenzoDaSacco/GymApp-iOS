import Foundation
import UserNotifications
import ActivityKit

@MainActor
final class RecoveryNotifications {
    static let shared = RecoveryNotifications()
    private init() {}

    private let endDatesKey = "gym.recovery.endDates.v3"
    private let notificationPrefix = "gym-recovery-"

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    @discardableResult
    func start(for setID: UUID, exerciseName: String, recovery: String) -> Date? {
        let recoveryText = recovery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "2:00" : recovery
        guard let seconds = Self.seconds(from: recoveryText), seconds > 0 else { return nil }

        // Remove expired/old Live Activities before creating the next one. This keeps one
        // recovery countdown visible at a time and prevents a pile-up on the Lock Screen.
        cleanupExpiredActivities()
        endAllLiveActivities(except: setID.uuidString)

        let id = notificationID(for: setID)
        let endDate = Date().addingTimeInterval(seconds)
        let content = UNMutableNotificationContent()
        content.title = "Recupero"
        content.body = "\(exerciseName) · timer in corso"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(request)

        saveEndDate(endDate, for: setID)
        startLiveActivity(setID: setID, exerciseName: exerciseName, recovery: recoveryText, endDate: endDate)
        return endDate
    }

    func cancel(for setID: UUID) {
        let center = UNUserNotificationCenter.current()
        let id = notificationID(for: setID)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
        removeEndDate(for: setID)
        endLiveActivity(setID: setID)
    }

    func endDate(for setID: UUID) -> Date? {
        storedEndDates()[setID.uuidString].flatMap(Date.init(timeIntervalSince1970:))
    }

    func cleanupExpiredActivities() {
        let now = Date()
        let dates = storedEndDates()
        for (id, timestamp) in dates where timestamp <= now.timeIntervalSince1970 {
            if let uuid = UUID(uuidString: id) {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationID(for: uuid)])
                endLiveActivity(setID: uuid)
            }
        }
        var remaining = dates
        remaining = remaining.filter { $0.value > now.timeIntervalSince1970 }
        UserDefaults.standard.set(remaining, forKey: endDatesKey)
    }

    static func seconds(from text: String) -> TimeInterval? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        if raw.contains(":") {
            let parts = raw.split(separator: ":").compactMap { Double($0) }
            if parts.count == 2 { return parts[0] * 60 + parts[1] }
        }
        if let n = Double(raw.replacingOccurrences(of: ",", with: ".")) { return n * 60 }
        return nil
    }

    private func startLiveActivity(setID: UUID, exerciseName: String, recovery: String, endDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endLiveActivity(setID: setID)

        let attributes = RecoveryActivityAttributes(setID: setID.uuidString)
        let state = RecoveryActivityAttributes.ContentState(endDate: endDate, exerciseName: exerciseName, recoveryText: recovery)
        do {
            _ = try Activity<RecoveryActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: endDate),
                pushType: nil
            )
        } catch {
            // The local notification remains available if Live Activities are unavailable.
        }
    }

    private func endAllLiveActivities(except id: String) {
        for activity in Activity<RecoveryActivityAttributes>.activities where activity.attributes.setID != id {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func endLiveActivity(setID: UUID) {
        let id = setID.uuidString
        for activity in Activity<RecoveryActivityAttributes>.activities where activity.attributes.setID == id {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func notificationID(for setID: UUID) -> String { "\(notificationPrefix)\(setID.uuidString)" }

    private func storedEndDates() -> [String: TimeInterval] {
        UserDefaults.standard.dictionary(forKey: endDatesKey) as? [String: TimeInterval] ?? [:]
    }

    private func saveEndDate(_ date: Date, for setID: UUID) {
        var dates = storedEndDates()
        dates[setID.uuidString] = date.timeIntervalSince1970
        UserDefaults.standard.set(dates, forKey: endDatesKey)
    }

    private func removeEndDate(for setID: UUID) {
        var dates = storedEndDates()
        dates.removeValue(forKey: setID.uuidString)
        UserDefaults.standard.set(dates, forKey: endDatesKey)
    }
}
