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
        return endDate
    }

    func cancel(for setID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID(for: setID)])
        removeEndDate(for: setID)
    }

    func endDate(for setID: UUID) -> Date? {
        storedEndDates()[setID.uuidString].flatMap(Date.init(timeIntervalSince1970:))
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
