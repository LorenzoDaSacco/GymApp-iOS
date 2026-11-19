import WidgetKit
import SwiftUI

// Unico widget dell'app: tasto rapido grande per aprire Gym Tracker Pro.
// I widget con contatori (scheda di oggi, serie, esercizi) sono stati rimossi:
// non mostravano dati aggiornati e dipendevano dall'App Group. Il codice resta
// recuperabile dalla cronologia Git (commit f42fbfe e precedenti).

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
        .description("Tasto rapido grande per aprire Gym Tracker Pro con un tocco. Non richiede la sincronizzazione dei dati.")
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
