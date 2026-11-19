import Foundation

/// One actual ten-minute interval containing at least one BLE heart-rate reading.
/// Empty intervals are deliberately not fabricated.
struct HeartRateBucket: Codable, Identifiable, Equatable {
    let slotStart: Date
    var count: Int
    var sumBPM: Int
    var minBPM: Int
    var maxBPM: Int
    var lastBPM: Int
    var lastReceivedAt: Date

    var id: Date { slotStart }
    var averageBPM: Double { count > 0 ? Double(sumBPM) / Double(count) : 0 }

    init(bpm: Int, date: Date) {
        slotStart = HeartRateHistory.slot(for: date)
        count = 1
        sumBPM = bpm
        minBPM = bpm
        maxBPM = bpm
        lastBPM = bpm
        lastReceivedAt = date
    }

    mutating func add(bpm: Int, date: Date) {
        count += 1
        sumBPM += bpm
        minBPM = min(minBPM, bpm)
        maxBPM = max(maxBPM, bpm)
        if date >= lastReceivedAt {
            lastBPM = bpm
            lastReceivedAt = date
        }
    }
}

struct HeartRateDaySummary: Identifiable {
    let date: Date
    let buckets: [HeartRateBucket]
    var id: Date { date }
    var intervalCount: Int { buckets.count }
    var averageBPM: Double? {
        guard !buckets.isEmpty else { return nil }
        // Equal weight for each observed ten-minute interval, not one vote per BLE notification.
        return buckets.reduce(0) { $0 + $1.averageBPM } / Double(buckets.count)
    }
    var minBPM: Int? { buckets.map(\.minBPM).min() }
    var maxBPM: Int? { buckets.map(\.maxBPM).max() }
}

enum HeartRateHistory {
    static let interval: TimeInterval = 10 * 60

    static func slot(for date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / interval) * interval)
    }

    static func record(bpm: Int, at date: Date, in buckets: inout [HeartRateBucket]) {
        guard (30...240).contains(bpm) else { return }
        let key = slot(for: date)
        if let index = buckets.firstIndex(where: { $0.slotStart == key }) {
            buckets[index].add(bpm: bpm, date: date)
        } else {
            buckets.append(HeartRateBucket(bpm: bpm, date: date))
            buckets.sort { $0.slotStart < $1.slotStart }
        }
    }

    static func summary(for date: Date, buckets: [HeartRateBucket], calendar: Calendar = .autoupdatingCurrent) -> HeartRateDaySummary {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return HeartRateDaySummary(date: start, buckets: buckets.filter { $0.slotStart >= start && $0.slotStart < end })
    }
}
