import Foundation
import UserNotifications

@MainActor
final class RecoveryNotifications {
    static let shared = RecoveryNotifications()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func start(for setID: UUID, exerciseName: String, recovery: String) {
        guard let seconds = Self.seconds(from: recovery), seconds > 0 else { return }
        let id = "gym-recovery-\(setID.uuidString)"
        let content = UNMutableNotificationContent()
        content.title = "Recupero terminato"
        content.body = "Puoi ripartire: \(exerciseName)"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancel(for setID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["gym-recovery-\(setID.uuidString)"])
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
}
