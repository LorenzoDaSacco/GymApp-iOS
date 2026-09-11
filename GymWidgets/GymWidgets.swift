import WidgetKit
import SwiftUI
import ActivityKit

struct GymDayEntry: TimelineEntry {
    let date: Date
    let day: String
    let exercises: [WidgetExercise]
}

struct GymDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> GymDayEntry { GymDayEntry(date: Date(), day: WidgetDay.today(), exercises: []) }
    func getSnapshot(in context: Context, completion: @escaping (GymDayEntry) -> Void) {
        completion(GymDayEntry(date: Date(), day: WidgetDay.today(), exercises: WidgetDataReader.todayExercises()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GymDayEntry>) -> Void) {
        let now = Date()
        let entry = GymDayEntry(date: now, day: WidgetDay.today(), exercises: WidgetDataReader.todayExercises())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
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
                        Text("\(exercise.sets.count)×\(exercise.sets.first?.reps ?? \"\")")
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
                .tint(.red)
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
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("RECUPERO").font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .font(.system(.caption, design: .monospaced).bold())
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .tint(.red)
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
        .description("Mostra automaticamente la scheda del giorno corrente.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct GymWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SchedaOggiWidget()
        RecoveryLiveActivityWidget()
    }
}
