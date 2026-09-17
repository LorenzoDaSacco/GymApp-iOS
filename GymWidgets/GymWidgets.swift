import WidgetKit
import SwiftUI

struct GymDayEntry: TimelineEntry {
    let date: Date
    let day: String
    let exercises: [WidgetExercise]
}

struct GymDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> GymDayEntry {
        GymDayEntry(date: Date(), day: WidgetDataReader.currentWorkoutDayLabel(), exercises: [])
    }
    func getSnapshot(in context: Context, completion: @escaping (GymDayEntry) -> Void) {
        completion(GymDayEntry(date: Date(), day: WidgetDataReader.currentWorkoutDayLabel(), exercises: WidgetDataReader.todayExercises()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GymDayEntry>) -> Void) {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let start = calendar.startOfDay(for: now)
        var entries: [GymDayEntry] = []
        entries.append(GymDayEntry(date: now, day: WidgetDataReader.currentWorkoutDayLabel(at: now), exercises: WidgetDataReader.todayExercises(at: now)))
        for offset in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            entries.append(GymDayEntry(date: date, day: WidgetDataReader.currentWorkoutDayLabel(at: date), exercises: WidgetDataReader.todayExercises(at: date)))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct GymProgressEntry: TimelineEntry {
    let date: Date
    let day: String
    let completedSets: Int
    let totalSets: Int
    let completedExercises: Int
    let totalExercises: Int
}

struct GymProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> GymProgressEntry {
        GymProgressEntry(date: Date(), day: WidgetDataReader.currentWorkoutDayLabel(), completedSets: 10, totalSets: 25, completedExercises: 1, totalExercises: 8)
    }
    func getSnapshot(in context: Context, completion: @escaping (GymProgressEntry) -> Void) {
        let p = WidgetDataReader.todayProgress()
        completion(GymProgressEntry(date: Date(), day: WidgetDataReader.currentWorkoutDayLabel(), completedSets: p.completedSets, totalSets: p.totalSets, completedExercises: p.completedExercises, totalExercises: p.totalExercises))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GymProgressEntry>) -> Void) {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let start = calendar.startOfDay(for: now)
        var entries: [GymProgressEntry] = []
        let today = WidgetDataReader.todayProgress(at: now)
        entries.append(GymProgressEntry(date: now, day: WidgetDataReader.currentWorkoutDayLabel(at: now), completedSets: today.completedSets, totalSets: today.totalSets, completedExercises: today.completedExercises, totalExercises: today.totalExercises))
        for offset in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let progress = WidgetDataReader.todayProgress(at: date)
            entries.append(GymProgressEntry(date: date, day: WidgetDataReader.currentWorkoutDayLabel(at: date), completedSets: progress.completedSets, totalSets: progress.totalSets, completedExercises: progress.completedExercises, totalExercises: progress.totalExercises))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct SchedaOggiWidgetView: View {
    let entry: GymDayEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(entry.day).font(.caption.bold()).foregroundStyle(.secondary)
            Text("Scheda di oggi").font(.headline.bold())
            if entry.exercises.isEmpty {
                Spacer(); Text("Giorno libero").font(.subheadline); Text("Nessun esercizio").font(.caption).foregroundStyle(.secondary); Spacer()
            } else {
                ForEach(Array(entry.exercises.prefix(6)), id: \.name) { exercise in
                    HStack(alignment: .firstTextBaseline) {
                        Text(exercise.name).font(.caption.bold()).lineLimit(1)
                        Spacer()
                        Text("\(exercise.sets.count) serie").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if entry.exercises.count > 6 { Text("+ altri \(entry.exercises.count - 6)").font(.caption2).foregroundStyle(.secondary) }
            }
        }
        .padding()
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

struct ProgressWidgetView: View {
    let entry: GymProgressEntry
    let mode: ProgressWidgetMode
    private var fraction: Double {
        let total = mode == .sets ? entry.totalSets : entry.totalExercises
        let done = mode == .sets ? entry.completedSets : entry.completedExercises
        return total > 0 ? min(1, Double(done) / Double(total)) : 0
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: mode == .sets ? "square.stack.3d.up.fill" : "figure.strengthtraining.traditional")
                .font(.title3)
            Text(mode == .sets ? "Serie" : "Esercizi").font(.caption.bold()).foregroundStyle(.secondary)
            Text(mode == .sets ? "\(entry.completedSets)/\(entry.totalSets)" : "\(entry.completedExercises)/\(entry.totalExercises)")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .monospacedDigit()
            ProgressView(value: fraction).tint(.accentColor)
            Text("Oggi").font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

struct CombinedProgressWidgetView: View {
    let entry: GymProgressEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 28)
                    Text("\(entry.completedExercises)/\(entry.totalExercises)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 28)
                    Text("\(entry.completedSets)/\(entry.totalSets)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(10)
            .containerBackground(for: .widget) { Color(.systemBackground) }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.day)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("OGGI")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                    Text("Esercizi").font(.headline.bold())
                    Spacer()
                    Text("\(entry.completedExercises)/\(entry.totalExercises)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .monospacedDigit()
                }

                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                    Text("Serie").font(.headline.bold())
                    Spacer()
                    Text("\(entry.completedSets)/\(entry.totalSets)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .monospacedDigit()
                }
            }
            .padding()
            .containerBackground(for: .widget) { Color(.systemBackground) }
        }
    }
}
struct CombinedProgressWidget: Widget {
    let kind = "CombinedProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GymProgressProvider()) { entry in
            CombinedProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("Esercizi e serie")
        .description("Mostra esercizi e serie completati oggi, ad esempio 1/8 e 10/30.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

enum ProgressWidgetMode { case sets, exercises }

struct SchedaOggiWidget: Widget {
    let kind = "SchedaOggiWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GymDayProvider()) { entry in SchedaOggiWidgetView(entry: entry) }
            .configurationDisplayName("Scheda di oggi")
            .description("Mostra gli esercizi previsti oggi.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SerieProgressWidget: Widget {
    let kind = "SerieProgressWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GymProgressProvider()) { entry in ProgressWidgetView(entry: entry, mode: .sets) }
            .configurationDisplayName("Serie completate")
            .description("Mostra quante serie hai completato oggi, ad esempio 10/25.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct EserciziProgressWidget: Widget {
    let kind = "EserciziProgressWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GymProgressProvider()) { entry in ProgressWidgetView(entry: entry, mode: .exercises) }
            .configurationDisplayName("Esercizi completati")
            .description("Mostra quanti esercizi hai completato oggi, ad esempio 1/8.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct GymWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SchedaOggiWidget()
        CombinedProgressWidget()
        SerieProgressWidget()
        EserciziProgressWidget()
        RecoveryLiveActivity()
    }
}
