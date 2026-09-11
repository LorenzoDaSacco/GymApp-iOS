import ActivityKit
import Foundation
import UserNotifications

@MainActor
final class RecoveryNotifications {
    static let shared = RecoveryNotifications()
    private init() {}

    private let endDatesKey = "gym.recovery.endDates.v1"

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    @discardableResult
    func start(for setID: UUID, exerciseName: String, recovery: String) -> Date? {
        guard let seconds = Self.seconds(from: recovery), seconds > 0 else { return nil }

        let id = notificationID(for: setID)
        let endDate = Date().addingTimeInterval(seconds)

        let content = UNMutableNotificationContent()
        content.title = "Recupero terminato"
        content.body = "Puoi ripartire: \(exerciseName)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(request)
        saveEndDate(endDate, for: setID)
        startLiveActivity(for: setID, exerciseName: exerciseName, duration: seconds, endDate: endDate)
        return endDate
    }

    func cancel(for setID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID(for: setID)])
        removeEndDate(for: setID)
        endLiveActivity(for: setID)
    }

    func endDate(for setID: UUID) -> Date? {
        storedEndDates()[setID.uuidString].flatMap(Date.init(timeIntervalSince1970:))
    }

    private func startLiveActivity(for setID: UUID, exerciseName: String, duration: TimeInterval, endDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            // Only one recovery Live Activity is shown at a time.
            for activity in Activity<RecoveryActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            let attributes = RecoveryActivityAttributes(
                setID: setID,
                exerciseName: exerciseName,
                duration: duration
            )
            let state = RecoveryActivityAttributes.ContentState(endDate: endDate)
            let content = ActivityContent(state: state, staleDate: endDate)

            do {
                _ = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                // The local notification remains the fallback if Live Activities are unavailable.
            }
        }
    }

    private func endLiveActivity(for setID: UUID) {
        Task {
            for activity in Activity<RecoveryActivityAttributes>.activities where activity.attributes.setID == setID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
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

    private func notificationID(for setID: UUID) -> String {
        "gym-recovery-\(setID.uuidString)"
    }

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
