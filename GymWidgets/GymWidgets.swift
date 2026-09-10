import WidgetKit
import SwiftUI

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
                        Text("\(exercise.sets.count)×\(exercise.sets.first?.reps ?? "")")
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
    var body: some Widget { SchedaOggiWidget() }
}
