import WidgetKit
import SwiftUI
import ActivityKit

struct GymDayEntry: TimelineEntry {
    let date: Date
    let day: String
    let exercises: [WidgetExercise]
}

struct GymProgressEntry: TimelineEntry {
    let date: Date
    let completed: Int
    let total: Int
}

struct GymExerciseProgressEntry: TimelineEntry {
    let date: Date
    let completed: Int
    let total: Int
}

struct GymDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> GymDayEntry { GymDayEntry(date: Date(), day: WidgetDay.today(), exercises: []) }
    func getSnapshot(in context: Context, completion: @escaping (GymDayEntry) -> Void) {
        completion(GymDayEntry(date: Date(), day: WidgetDay.today(), exercises: WidgetDataReader.todayExercises()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GymDayEntry>) -> Void) {
        let now = Date()
        let entry = GymDayEntry(date: now, day: WidgetDay.today(), exercises: WidgetDataReader.todayExercises())
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct GymProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> GymProgressEntry { GymProgressEntry(date: Date(), completed: 0, total: 0) }
    func getSnapshot(in context: Context, completion: @escaping (GymProgressEntry) -> Void) {
        let counts = WidgetDataReader.completedSetsCount()
        completion(GymProgressEntry(date: Date(), completed: counts.completed, total: counts.total))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GymProgressEntry>) -> Void) {
        let now = Date()
        let counts = WidgetDataReader.completedSetsCount()
        let entry = GymProgressEntry(date: now, completed: counts.completed, total: counts.total)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct GymExerciseProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> GymExerciseProgressEntry { GymExerciseProgressEntry(date: Date(), completed: 0, total: 0) }
    func getSnapshot(in context: Context, completion: @escaping (GymExerciseProgressEntry) -> Void) {
        let counts = WidgetDataReader.completedExercisesCount()
        completion(GymExerciseProgressEntry(date: Date(), completed: counts.completed, total: counts.total))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GymExerciseProgressEntry>) -> Void) {
        let now = Date()
        let counts = WidgetDataReader.completedExercisesCount()
        let entry = GymExerciseProgressEntry(date: now, completed: counts.completed, total: counts.total)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct SchedaOggiWidgetView: View {
    let entry: GymDayEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(entry.day).font(.caption.bold()).foregroundStyle(.secondary)
            Text("Scheda di oggi").font(.headline.bold())
            if entry.exercises.isEmpty {
                Spacer()
                Text("Giorno libero").font(.subheadline)
                Text("Nessun esercizio").font(.caption).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(Array(entry.exercises.prefix(6)), id: \.name) { exercise in
                    HStack(alignment: .firstTextBaseline) {
                        Text(exercise.name).font(.caption.bold()).lineLimit(1)
                        Spacer()
                        Text("\(exercise.sets.count) serie")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if entry.exercises.count > 6 {
                    Text("+ altri \(entry.exercises.count - 6)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }.padding()
    }
}

struct ProgressWidgetView: View {
    let entry: GymProgressEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").font(.title2)
            Text("SERIE").font(.caption.bold()).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("\(entry.completed)/\(entry.total)")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
            Text("completate oggi").font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct ExerciseProgressWidgetView: View {
    let entry: GymExerciseProgressEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "dumbbell.fill").font(.title2)
            Text("ESERCIZI").font(.caption.bold()).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("\(entry.completed)/\(entry.total)")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
            Text("completati oggi").font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct RecoveryLiveActivityView: View {
    let context: ActivityViewContext<RecoveryActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "timer")
                Text("RECUPERO").font(.caption.bold())
                Spacer()
                Text(context.state.exerciseName).font(.caption).lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                Spacer()
                Text("restante").font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(timerInterval: Date()...context.state.endDate, countsDown: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .activityBackgroundTint(Color.black.opacity(0.92))
        .activitySystemActionForegroundColor(.white)
    }
}

struct RecoveryLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecoveryActivityAttributes.self) { context in
            RecoveryLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "timer") }
                DynamicIslandExpandedRegion(.center) { Text("RECUPERO").font(.caption.bold()) }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .font(.system(.caption, design: .monospaced).bold())
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: Date()...context.state.endDate, countsDown: true)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .font(.system(size: 12, design: .monospaced).bold())
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
            }
            .widgetURL(nil)
            .keylineTint(.red)
        }
    }
}

struct SchedaOggiWidget: Widget {
    let kind = "SchedaOggiWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GymDayProvider()) { entry in
            SchedaOggiWidgetView(entry: entry)
        }
        .configurationDisplayName("Scheda di oggi")
        .description("Mostra gli esercizi del giorno corrente.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SerieCompletateWidget: Widget {
    let kind = "SerieCompletateWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GymProgressProvider()) { entry in
            ProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("Serie completate")
        .description("Mostra quante serie hai completato oggi.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct EserciziCompletatiWidget: Widget {
    let kind = "EserciziCompletatiWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GymExerciseProgressProvider()) { entry in
            ExerciseProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("Esercizi completati")
        .description("Mostra quanti esercizi hai completato oggi.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct GymWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SchedaOggiWidget()
        SerieCompletateWidget()
        EserciziCompletatiWidget()
        RecoveryLiveActivityWidget()
    }
}
