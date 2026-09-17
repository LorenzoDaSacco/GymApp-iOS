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
        let now = Date()
        let entry = GymDayEntry(date: now, day: WidgetDataReader.currentWorkoutDayLabel(), exercises: WidgetDataReader.todayExercises())
        let calendar = Calendar.current
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct GymProgressEntry: TimelineEntry {
    let date: Date
    let completedSets: Int
    let totalSets: Int
    let completedExercises: Int
    let totalExercises: Int
}

struct GymProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> GymProgressEntry {
        GymProgressEntry(date: Date(), completedSets: 10, totalSets: 25, completedExercises: 1, totalExercises: 8)
    }
    func getSnapshot(in context: Context, completion: @escaping (GymProgressEntry) -> Void) {
        let p = WidgetDataReader.todayProgress()
        completion(GymProgressEntry(date: Date(), completedSets: p.completedSets, totalSets: p.totalSets, completedExercises: p.completedExercises, totalExercises: p.totalExercises))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GymProgressEntry>) -> Void) {
        let now = Date()
        let p = WidgetDataReader.todayProgress()
        let entry = GymProgressEntry(date: now, completedSets: p.completedSets, totalSets: p.totalSets, completedExercises: p.completedExercises, totalExercises: p.totalExercises)
        let calendar = Calendar.current
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
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
        SerieProgressWidget()
        EserciziProgressWidget()
        RecoveryLiveActivity()
    }
}
