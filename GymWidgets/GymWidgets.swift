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
        let entry = GymDayEntry(
            date: now,
            day: WidgetDataReader.currentWorkoutDayLabel(at: now),
            exercises: WidgetDataReader.todayExercises(at: now)
        )
        let start = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(24 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
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
        let p = WidgetDataReader.todayProgress(at: now)
        let entry = GymProgressEntry(
            date: now,
            day: WidgetDataReader.currentWorkoutDayLabel(at: now),
            completedSets: p.completedSets,
            totalSets: p.totalSets,
            completedExercises: p.completedExercises,
            totalExercises: p.totalExercises
        )
        let start = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(24 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

}

struct SchedaOggiWidgetView: View {
    let entry: GymDayEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(entry.day).font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill").foregroundStyle(.purple)
                Text("TRAINING").font(.caption.bold()).tracking(1.2)
            }
            Text("Scheda di oggi").font(.headline.bold())
            if entry.exercises.isEmpty {
                Spacer(); Text("Giorno libero").font(.subheadline); Text("Nessun esercizio").font(.caption).foregroundStyle(.secondary); Spacer()
            } else {
                ForEach(Array(entry.exercises.prefix(6).enumerated()), id: \.offset) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.element.name).font(.caption.bold()).lineLimit(1)
                        Spacer()
                        Text("\(item.element.sets.count) serie").font(.caption2).foregroundStyle(.secondary)
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
                .font(.title3).foregroundStyle(.purple)
            Text(mode == .sets ? "Serie" : "Esercizi").font(.caption.bold()).foregroundStyle(.secondary)
            Text(mode == .sets ? "\(entry.completedSets)/\(entry.totalSets)" : "\(entry.completedExercises)/\(entry.totalExercises)")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .monospacedDigit()
            ProgressView(value: fraction).tint(.purple)
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


// Widget indipendente dai dati locali: apre l'app anche se la sincronizzazione
// dell'App Group non e disponibile con il profilo di firma utilizzato.
struct GymLauncherEntry: TimelineEntry { let date: Date }

struct GymLauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> GymLauncherEntry { GymLauncherEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (GymLauncherEntry) -> Void) {
        completion(GymLauncherEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GymLauncherEntry>) -> Void) {
        completion(Timeline(entries: [GymLauncherEntry(date: Date())], policy: .never))
    }
}

struct GymLauncherView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: family == .systemSmall ? 26 : 32, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.52, blue: 0.54))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer(minLength: 8)
            Text("GYM")
                .font(.system(size: family == .systemSmall ? 30 : 36, weight: .black, design: .rounded))
                .tracking(-1.2)
                .foregroundStyle(.white)
            Text("TRACKER PRO")
                .font(.system(size: family == .systemSmall ? 11 : 14, weight: .heavy, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(Color(red: 1, green: 0.52, blue: 0.54))
            Text("Tocca per allenarti  →")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(family == .systemSmall ? 16 : 22)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0.14, green: 0.15, blue: 0.20),
                                     Color(red: 0.055, green: 0.065, blue: 0.10)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct GymLauncherWidget: Widget {
    let kind = "GymLauncherWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GymLauncherProvider()) { _ in
            GymLauncherView()
        }
        .configurationDisplayName("Apri Gym Tracker Pro")
        .description("Collegamento rapido per aprire Gym Tracker Pro. Non richiede la sincronizzazione dei dati.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct GymWidgetsBundle: WidgetBundle {
    var body: some Widget {
        GymLauncherWidget()
        RecoveryLiveActivity()
    }
}
