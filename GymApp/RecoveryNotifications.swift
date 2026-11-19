import Foundation
import UserNotifications
import ActivityKit

@MainActor
final class RecoveryNotifications {
    static let shared = RecoveryNotifications()
    private init() {}

    private let endDatesKey = "gym.recovery.endDates.v3"
    private let activeSetKey = "gym.recovery.activeSet.v1"

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    @discardableResult
    func start(for setID: UUID, exerciseName: String, recovery: String) -> Date? {
        let recoveryText = recovery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "2:00" : recovery
        guard let seconds = Self.seconds(from: recoveryText), seconds > 0 else { return nil }

        // Un solo recupero attivo alla volta: la nuova serie diventa quella mostrata
        // sia dentro l'app sia nella Live Activity/Dynamic Island.
        cancelAllOtherTimers(except: setID)

        let endDate = Date().addingTimeInterval(seconds)
        saveEndDate(endDate, for: setID)
        UserDefaults.standard.set(setID.uuidString, forKey: activeSetKey)

        let center = UNUserNotificationCenter.current()
        let id = notificationID(for: setID)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])

        // Piccolo avviso immediato. Il conto alla rovescia vero e proprio è gestito
        // dalla Live Activity/Dynamic Island e dalla vista del timer nell'app.
        let content = UNMutableNotificationContent()
        content.title = "Recupero · \(recoveryText)"
        content.body = exerciseName
        content.sound = nil
        content.interruptionLevel = .passive
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        center.add(request)

        startLiveActivity(setID: setID, exerciseName: exerciseName, recovery: recoveryText, endDate: endDate)

        // Quando l'app resta viva, chiude automaticamente la Live Activity allo 0:00.
        // Se iOS sospende/termina l'app, staleDate continua comunque a gestire il countdown.
        Task { [weak self] in
            let ns = UInt64(seconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { return }
            self?.finish(setID: setID)
        }
        return endDate
    }

    func cancel(for setID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID(for: setID)])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationID(for: setID), doneNotificationID(for: setID)])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [doneNotificationID(for: setID)])
        removeEndDate(for: setID)
        if UserDefaults.standard.string(forKey: activeSetKey) == setID.uuidString {
            UserDefaults.standard.removeObject(forKey: activeSetKey)
        }
        endLiveActivity(setID: setID)
    }

    func cleanupExpired() {
        let now = Date()
        let dates = storedEndDates()
        for (idString, timestamp) in dates where timestamp <= now.timeIntervalSince1970 {
            if let id = UUID(uuidString: idString) { finish(setID: id) }
        }
    }

    func endDate(for setID: UUID) -> Date? {
        storedEndDates()[setID.uuidString].map(Date.init(timeIntervalSince1970:))
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

    private func finish(setID: UUID) {
        guard let end = endDate(for: setID), end <= Date().addingTimeInterval(0.25) else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID(for: setID)])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationID(for: setID)])
        removeEndDate(for: setID)
        if UserDefaults.standard.string(forKey: activeSetKey) == setID.uuidString {
            UserDefaults.standard.removeObject(forKey: activeSetKey)
        }
        endLiveActivity(setID: setID)

        let content = UNMutableNotificationContent()
        content.title = "Recupero terminato"
        content.body = "Puoi ripartire"
        content.sound = .default
        content.interruptionLevel = .active
        let doneID = doneNotificationID(for: setID)
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: doneID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
        ))
    }

    private func cancelAllOtherTimers(except setID: UUID) {
        let dates = storedEndDates()
        for idString in dates.keys {
            guard let id = UUID(uuidString: idString), id != setID else { continue }
            cancel(for: id)
        }
        if let active = UserDefaults.standard.string(forKey: activeSetKey), active != setID.uuidString,
           let id = UUID(uuidString: active) {
            endLiveActivity(setID: id)
        }
    }

    private func startLiveActivity(setID: UUID, exerciseName: String, recovery: String, endDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endAllLiveActivities()
        let attributes = RecoveryActivityAttributes(setID: setID.uuidString)
        let state = RecoveryActivityAttributes.ContentState(endDate: endDate, exerciseName: exerciseName, recoveryText: recovery)
        do {
            _ = try Activity<RecoveryActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: endDate),
                pushType: nil
            )
        } catch { }
    }

    private func endLiveActivity(setID: UUID) {
        let id = setID.uuidString
        for activity in Activity<RecoveryActivityAttributes>.activities where activity.attributes.setID == id {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func endAllLiveActivities() {
        for activity in Activity<RecoveryActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func notificationID(for setID: UUID) -> String { "gym-recovery-\(setID.uuidString)" }
    private func doneNotificationID(for setID: UUID) -> String { "gym-recovery-done-\(setID.uuidString)" }

    private func storedEndDates() -> [String: TimeInterval] {
        UserDefaults.standard.dictionary(forKey: endDatesKey) as? [String: TimeInterval] ?? [:]
    }

    private func saveEndDate(_ date: Date, for setID: UUID) {
        var dates = storedEndDates(); dates[setID.uuidString] = date.timeIntervalSince1970
        UserDefaults.standard.set(dates, forKey: endDatesKey)
    }

    private func removeEndDate(for setID: UUID) {
        var dates = storedEndDates(); dates.removeValue(forKey: setID.uuidString)
        UserDefaults.standard.set(dates, forKey: endDatesKey)
    }
}
