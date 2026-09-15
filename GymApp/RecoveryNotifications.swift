import Foundation
import UserNotifications
import ActivityKit

@MainActor
final class RecoveryNotifications {
    static let shared = RecoveryNotifications()
    private init() {}

    private let endDatesKey = "gym.recovery.endDates.v3"
    private let pausedKey = "gym.recovery.pausedRemaining.v1"
    private let durationsKey = "gym.recovery.durations.v1"

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    @discardableResult
    func start(for setID: UUID, exerciseName: String, recovery: String) -> Date? {
        let recoveryText = recovery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "2:00" : recovery
        guard let seconds = Self.seconds(from: recoveryText), seconds > 0 else { return nil }
        return start(for: setID, exerciseName: exerciseName, seconds: seconds, recoveryText: recoveryText)
    }

    @discardableResult
    private func start(for setID: UUID, exerciseName: String, seconds: TimeInterval, recoveryText: String) -> Date? {
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
        saveDuration(seconds, for: setID)
        removePaused(for: setID)
        startLiveActivity(setID: setID, exerciseName: exerciseName, recovery: recoveryText, endDate: endDate)
        return endDate
    }

    func pause(for setID: UUID) {
        guard let endDate = endDate(for: setID) else { return }
        let remaining = max(0, endDate.timeIntervalSinceNow)
        guard remaining > 0 else { return }
        savePausedRemaining(remaining, for: setID)
        removeEndDate(for: setID)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID(for: setID)])
        endLiveActivity(setID: setID)
    }

    @discardableResult
    func resume(for setID: UUID, exerciseName: String, recoveryText: String) -> Date? {
        guard let remaining = pausedRemaining(for: setID), remaining > 0 else { return nil }
        return start(for: setID, exerciseName: exerciseName, seconds: remaining, recoveryText: recoveryText)
    }

    @discardableResult
    func adjust(for setID: UUID, seconds delta: TimeInterval, exerciseName: String, recoveryText: String) -> Date? {
        let currentRemaining: TimeInterval
        if let paused = pausedRemaining(for: setID) {
            currentRemaining = paused
        } else if let end = endDate(for: setID) {
            currentRemaining = max(0, end.timeIntervalSinceNow)
        } else {
            return nil
        }

        let newRemaining = max(5, currentRemaining + delta)
        return start(for: setID, exerciseName: exerciseName, seconds: newRemaining, recoveryText: recoveryText)
    }

    func skip(for setID: UUID) {
        cancel(for: setID)
    }

    func cancel(for setID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID(for: setID)])
        removeEndDate(for: setID)
        removePaused(for: setID)
        removeDuration(for: setID)
        endLiveActivity(setID: setID)
    }

    func endDate(for setID: UUID) -> Date? {
        storedEndDates()[setID.uuidString].flatMap(Date.init(timeIntervalSince1970:))
    }

    func pausedRemaining(for setID: UUID) -> TimeInterval? {
        storedPaused()[setID.uuidString]
    }

    func remaining(for setID: UUID, now: Date = Date()) -> TimeInterval? {
        if let paused = pausedRemaining(for: setID) { return paused }
        guard let end = endDate(for: setID) else { return nil }
        return max(0, end.timeIntervalSince(now))
    }

    func isPaused(for setID: UUID) -> Bool {
        pausedRemaining(for: setID) != nil
    }

    func duration(for setID: UUID, fallback: TimeInterval = 120) -> TimeInterval {
        storedDurations()[setID.uuidString] ?? fallback
    }

    static func seconds(from text: String) -> TimeInterval? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        if raw.contains(":") {
            let parts = raw.split(separator: ":").compactMap { Double($0) }
            if parts.count == 2 {
                return parts[0] * 60 + parts[1]
            }
        }
        if let n = Double(raw.replacingOccurrences(of: ",", with: ".")) {
            return n * 60
        }
        return nil
    }

    private func startLiveActivity(setID: UUID, exerciseName: String, recovery: String, endDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        endLiveActivity(setID: setID)

        let attributes = RecoveryActivityAttributes(setID: setID.uuidString)
        let state = RecoveryActivityAttributes.ContentState(
            endDate: endDate,
            exerciseName: exerciseName,
            recoveryText: recovery
        )

        do {
            _ = try Activity<RecoveryActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: endDate),
                pushType: nil
            )
        } catch {
            // La notifica locale resta disponibile anche se le Live Activity sono disabilitate.
        }
    }

    private func endLiveActivity(setID: UUID) {
        let id = setID.uuidString
        for activity in Activity<RecoveryActivityAttributes>.activities where activity.attributes.setID == id {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func notificationID(for setID: UUID) -> String {
        "gym-recovery-\(setID.uuidString)"
    }

    private func storedEndDates() -> [String: TimeInterval] {
        UserDefaults.standard.dictionary(forKey: endDatesKey) as? [String: TimeInterval] ?? [:]
    }

    private func storedPaused() -> [String: TimeInterval] {
        UserDefaults.standard.dictionary(forKey: pausedKey) as? [String: TimeInterval] ?? [:]
    }

    private func storedDurations() -> [String: TimeInterval] {
        UserDefaults.standard.dictionary(forKey: durationsKey) as? [String: TimeInterval] ?? [:]
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

    private func savePausedRemaining(_ value: TimeInterval, for setID: UUID) {
        var values = storedPaused()
        values[setID.uuidString] = value
        UserDefaults.standard.set(values, forKey: pausedKey)
    }

    private func removePaused(for setID: UUID) {
        var values = storedPaused()
        values.removeValue(forKey: setID.uuidString)
        UserDefaults.standard.set(values, forKey: pausedKey)
    }

    private func saveDuration(_ value: TimeInterval, for setID: UUID) {
        var values = storedDurations()
        values[setID.uuidString] = value
        UserDefaults.standard.set(values, forKey: durationsKey)
    }

    private func removeDuration(for setID: UUID) {
        var values = storedDurations()
        values.removeValue(forKey: setID.uuidString)
        UserDefaults.standard.set(values, forKey: durationsKey)
    }
}
