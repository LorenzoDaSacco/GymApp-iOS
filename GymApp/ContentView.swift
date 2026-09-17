import SwiftUI
import Charts
import Combine

enum AccentColorOption: String, CaseIterable, Identifiable {
    case purple, blue, green, orange, red, pink, teal, yellow, indigo, mint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .purple: return "Viola"
        case .blue: return "Blu"
        case .green: return "Verde"
        case .orange: return "Arancione"
        case .red: return "Rosso"
        case .pink: return "Rosa"
        case .teal: return "Turchese"
        case .yellow: return "Giallo"
        case .indigo: return "Indaco"
        case .mint: return "Menta"
        }
    }

    var color: Color {
        switch self {
        case .purple: return .purple
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        case .teal: return .teal
        case .yellow: return .yellow
        case .indigo: return .indigo
        case .mint: return .mint
        }
    }
}

private struct GymAccentColorKey: EnvironmentKey {
    static let defaultValue: Color = .purple
}

extension EnvironmentValues {
    var gymAccentColor: Color {
        get { self[GymAccentColorKey.self] }
        set { self[GymAccentColorKey.self] = newValue }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("gymapp.darkMode") private var darkMode = true
    @AppStorage("gymapp.accentColor") private var accentColorName = AccentColorOption.purple.rawValue
    @State private var selectedTab = 0

    private var accentColor: Color { AccentColorOption(rawValue: accentColorName)?.color ?? .purple }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(store: store)
            }
            .tabItem { Label("Scheda", systemImage: "list.bullet.clipboard") }
            .tag(0)

            NavigationStack {
                AnalyticsView(store: store)
            }
            .tabItem { Label("Progressi", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(1)

            NavigationStack {
                AddExerciseView(store: store) { selectedTab = 0 }
            }
            .tabItem { Label("Aggiungi", systemImage: "plus.circle") }
            .tag(2)

            NavigationStack {
                SettingsView(store: store, darkMode: $darkMode, accentColorName: $accentColorName)
            }
            .tabItem { Label("Impostazioni", systemImage: "gearshape") }
            .tag(3)
        }
        .tint(accentColor)
        .environment(\.gymAccentColor, accentColor)
        .preferredColorScheme(darkMode ? .dark : .light)
        .onAppear {
            store.refreshSelectedDayForToday()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                RecoveryNotifications.shared.cleanupExpired()
                store.refreshSelectedDayForToday()
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            if scenePhase == .active { store.refreshSelectedDayForToday() }
        }
    }
}

struct DashboardView: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("GYM TRACKER PRO")
                        .font(.system(size: 26, weight: .black))
                    Spacer()
                    Image(systemName: "dumbbell.fill")
                        .font(.title3)
                        .padding(10)
                        .background(accentColor.opacity(0.15), in: .circle)
                }

                Picker("Giorno", selection: $store.selectedDay) {
                    ForEach(store.days, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Metric(title: "Esercizi", value: "\(store.dayExercises.count)", icon: "figure.strengthtraining.traditional")
                    Metric(title: "Serie", value: "\(store.totalSets)", icon: "square.stack.3d.up")
                    Metric(title: "Completate", value: "\(store.completedSets)", icon: "checkmark.circle")
                }

                SwiftUI.ProgressView(value: store.totalSets == 0 ? 0 : Double(store.completedSets) / Double(store.totalSets))
                    .tint(accentColor)

                if store.dayExercises.isEmpty {
                    EmptyDayView()
                } else {
                    ForEach(store.dayExercises) { exercise in
                        ExerciseCard(store: store, exercise: exercise)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(store.selectedDay)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") { store.resetDay() }
            }
        }
    }
}

struct Metric: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
            Text(value).font(.title2.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct EmptyDayView: View {
    var body: some View {
        ContentUnavailableView(
            "Giorno libero",
            systemImage: "calendar.badge.plus",
            description: Text("Aggiungi gli esercizi che vuoi per questo giorno.")
        )
    }
}

struct ExerciseCard: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    let exercise: Exercise
    @State private var editing = false
    @State private var showingDeleteConfirmation = false
    @State private var targetRepsDraft = ""
    @AppStorage("gymapp.showMuscleMap") private var showMuscleMap = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name).font(.headline)
                    Text(exercise.group).font(.caption.bold()).foregroundStyle(accentColor)
                    Text(exercise.focus).font(.caption).foregroundStyle(.secondary)
                    Text("Scheda: \(exercise.sets.count) serie \(exercise.targetReps)")
                        .font(.caption.bold()).foregroundStyle(accentColor)
                }
                Spacer()
                Button(editing ? "Fine" : "Modifica") {
                    if editing { commitTargetReps() }
                    else { targetRepsDraft = exercise.targetReps }
                    editing.toggle()
                }
            }

            RecoveryTimerSection(store: store, exercise: exercise, editing: editing, accentColor: accentColor)

            if editing {
                HStack(spacing: 10) {
                    Text("Ripetizioni")
                        .font(.caption.bold())
                    TextField("8-10", text: $targetRepsDraft)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                        .frame(width: 110)
                        .onSubmit { commitTargetReps() }
                    Spacer()
                }
                .onAppear { targetRepsDraft = exercise.targetReps }
                .onChange(of: exercise.targetReps) { _, newValue in
                    if targetRepsDraft != newValue { targetRepsDraft = newValue }
                }

                Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                    Label("Elimina esercizio", systemImage: "trash")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Toggle(isOn: Binding(
                    get: { exercise.backOffEnabled },
                    set: { store.setBackOffEnabled($0, exerciseID: exercise.id) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Back-off ultima serie").font(.caption.bold())
                        Text("Ultima serie = 80% della serie precedente").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .tint(accentColor)
            }

            HStack(spacing: 10) {
                Text("SERIE").frame(width: 34, alignment: .leading)
                if store.repetitionMode == .perSet { Text("REPS").frame(width: 58, alignment: .leading) }
                Text("PESO").frame(width: 82, alignment: .leading)
                Spacer()
                Text("✓").frame(width: 32)
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                SetRow(store: store, exercise: exercise, index: index, set: set, editing: editing)
            }

            HStack {
                Button("+ Serie") { store.addSet(to: exercise.id) }.buttonStyle(.bordered)
                Button("− Serie") { store.removeSet(from: exercise.id) }.buttonStyle(.bordered)
                Spacer()
                Text("\(exercise.sets.count) serie").font(.caption).foregroundStyle(.secondary)
            }

            if showMuscleMap {
                MuscleMapView(target: exercise.target)
                    .frame(height: 185)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(accentColor.opacity(0.15)))
        .alert("Eliminare esercizio?", isPresented: $showingDeleteConfirmation) {
            Button("Elimina", role: .destructive) { store.remove(exercise) }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("L'esercizio e tutte le sue serie verranno rimossi dalla scheda.")
        }
    }

    private func commitTargetReps() {
        let value = targetRepsDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            targetRepsDraft = exercise.targetReps
            return
        }
        store.setTargetReps(value, exerciseID: exercise.id)
        targetRepsDraft = value
    }
}

struct RecoveryTimerSection: View {
    @ObservedObject var store: WorkoutStore
    let exercise: Exercise
    let editing: Bool
    let accentColor: Color
    @State private var recoveryText = ""
    @FocusState private var recoveryFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text("Recupero").font(.caption.bold())
                TextField("2:00", text: $recoveryText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .focused($recoveryFocused)
                    .disabled(!editing)
                    .onAppear { recoveryText = exercise.recovery }
                    .onChange(of: recoveryFocused) { _, isFocused in if !isFocused { commitRecovery() } }
                    .onChange(of: exercise.recovery) { _, newValue in if !recoveryFocused { recoveryText = newValue } }
                Spacer()
                Text(exercise.target.title)
                    .font(.caption2)
                    .padding(7)
                    .background(accentColor.opacity(0.12), in: Capsule())
            }

            if let setID = activeTimerSetID {
                RecoveryCountdownView(setID: setID, duration: RecoveryNotifications.seconds(from: exercise.recovery) ?? 120, accentColor: accentColor)
            }
        }
    }

    private func commitRecovery() {
        let value = recoveryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value != exercise.recovery else { return }
        store.setRecovery(value, exerciseID: exercise.id)
    }

    private var activeTimerSetID: UUID? {
        let now = Date()
        return exercise.sets.compactMap { set -> (UUID, Date)? in
            guard let endDate = RecoveryNotifications.shared.endDate(for: set.id), endDate > now else { return nil }
            return (set.id, endDate)
        }.max(by: { $0.1 < $1.1 })?.0
    }
}

struct RecoveryCountdownView: View {
    let setID: UUID
    let duration: TimeInterval
    let accentColor: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let endDate = RecoveryNotifications.shared.endDate(for: setID)
            let remaining = max(0, (endDate ?? context.date).timeIntervalSince(context.date))
            let progress = duration > 0 ? min(1, max(0, remaining / duration)) : 0
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(remaining > 0 ? formattedTime(remaining) : "PRONTO")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(remaining > 0 ? .primary : accentColor)
                    Spacer()
                    Text(remaining > 0 ? "Tempo restante" : "Puoi ripartire")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                ProgressView(value: progress, total: 1).tint(accentColor)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let total = Int(ceil(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct SetRow: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    let exercise: Exercise
    let index: Int
    let set: WorkoutSet
    let editing: Bool
    @State private var weightDraft = ""
    @State private var repsDraft = ""
    @FocusState private var focus: Field?

    private enum Field: Hashable { case weight, reps }

    var body: some View {
        HStack(spacing: 10) {
            Text("S\(index + 1)")
                .font(.caption.bold())
                .frame(width: 34, alignment: .leading)

            // Modalità generale: il target è unico per tutto l'esercizio
            // e ogni serie mostra/modifica soltanto il proprio peso.
            // Modalità per serie: ogni serie ha le proprie reps effettive + peso.
            if store.repetitionMode == .perSet {
                TextField("reps", text: $repsDraft)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 58)
                    .focused($focus, equals: .reps)
                    .disabled(!editing)
                    .onAppear { syncDrafts() }
                    .onChange(of: focus) { _, newFocus in
                        if newFocus != .reps { commitReps() }
                    }
            }

            if set.isBackOff {
                Text(format(store.backOffWeight(exerciseID: exercise.id)))
                    .font(.body.bold())
                    .frame(width: 82, alignment: .leading)
            } else {
                TextField("kg", text: $weightDraft)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 82)
                    .focused($focus, equals: .weight)
                    .disabled(!editing)
                    .onAppear { syncDrafts() }
                    .onChange(of: set.weight) { _, _ in
                        if focus != .weight { syncWeight() }
                    }
                    .onChange(of: focus) { _, newFocus in
                        if newFocus != .weight { commitWeight() }
                    }
            }

            Spacer()

            Button {
                commitBeforeToggle()
                focus = nil
                store.toggle(exercise.id, setID: set.id)
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.completed ? accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 32)
        }
        .contentShape(Rectangle())
        .onAppear { syncDrafts() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fine") { focus = nil }
            }
        }
    }

    private func syncDrafts() {
        if weightDraft.isEmpty { weightDraft = format(set.weight) }
        if repsDraft.isEmpty { repsDraft = set.reps }
    }

    private func syncWeight() {
        weightDraft = format(set.weight)
    }

    private func commitBeforeToggle() {
        commitWeight()
        commitReps()
    }

    private func commitWeight() {
        guard !set.isBackOff else { return }
        let raw = weightDraft
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(raw), value > 0 else {
            weightDraft = format(set.weight)
            return
        }
        store.updateWeight(value, exerciseID: exercise.id, setID: set.id)
        weightDraft = format(value)
    }

    private func commitReps() {
        guard store.repetitionMode == .perSet else { return }
        let value = repsDraft.filter(\.isNumber).prefix(3).description
        if value != set.reps {
            store.setReps(value, exerciseID: exercise.id, setID: set.id)
        }
    }

    private func format(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".0", with: "")
    }
}

// MARK: - PROGRESSI

struct AnalyticsView: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    @State private var selectedDay: String?

    private var activeDays: [String] {
        store.days.filter { day in store.exercises.contains { $0.day == day } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Progressi").font(.largeTitle.bold())
                Text("I tuoi allenamenti sono organizzati per giornata. Apri una scheda per vedere gli esercizi e poi entra nel singolo esercizio per il grafico dei kg.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if activeDays.isEmpty {
                    ContentUnavailableView("Nessun allenamento", systemImage: "chart.line.uptrend.xyaxis")
                } else {
                    ForEach(activeDays, id: \.self) { day in
                        DayProgressCard(store: store, day: day) {
                            selectedDay = day
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Progressi")
        .sheet(isPresented: Binding(
            get: { selectedDay != nil },
            set: { if !$0 { selectedDay = nil } }
        )) {
            if let day = selectedDay {
                NavigationStack {
                    DayProgressView(store: store, day: day)
                }
            }
        }
    }
}

struct DayProgressCard: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    let day: String
    let action: () -> Void

    private var exercises: [Exercise] { store.exercises.filter { $0.day == day } }
    private var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    private var muscles: String {
        Array(Set(exercises.map { $0.target.title })).prefix(3).joined(separator: " • ")
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(day).font(.title3.bold())
                        Text(workoutName(for: day)).font(.caption.bold()).foregroundStyle(accentColor)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    SummaryPill(value: "\(exercises.count)", label: "esercizi")
                    SummaryPill(value: "\(totalSets)", label: "serie")
                    Spacer()
                }

                if !muscles.isEmpty {
                    Text(muscles)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    private func workoutName(for day: String) -> String {
        switch day {
        case "LUNEDÌ": return "UPPER"
        case "MARTEDÌ": return "LOWER"
        case "MERCOLEDÌ": return "FULLBODY"
        default: return "ALLENAMENTO"
        }
    }
}

struct SummaryPill: View {
    @Environment(\.gymAccentColor) private var accentColor
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.headline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DayProgressView: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    let day: String

    private var exercises: [Exercise] { store.exercises.filter { $0.day == day } }

    var body: some View {
        List {
            Section {
                ForEach(exercises) { exercise in
                    NavigationLink {
                        ExerciseHistoryView(store: store, exercise: exercise)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: exercise.target))
                                .frame(width: 28)
                                .foregroundStyle(accentColor)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.name).font(.headline)
                                Text("\(exercise.sets.count) serie • \(exercise.target.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(format(store.maxWeight(for: exercise))) kg")
                                .font(.caption.bold())
                        }
                        .padding(.vertical, 5)
                    }
                }
            } header: {
                Text("Esercizi")
            }
        }
        .navigationTitle(day)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func icon(for target: MuscleTarget) -> String {
        switch target {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "arrow.left.and.right"
        case .shoulders: return "figure.arms.open"
        case .biceps, .triceps: return "figure.strengthtraining.functional"
        case .quads, .hamstrings: return "figure.walk"
        case .fullBody: return "figure.mixed.cardio"
        }
    }

    private func format(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".0", with: "")
    }
}

struct ExerciseHistoryView: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    let exercise: Exercise

    private var history: [WeightLog] { store.history(for: exercise) }
    private var currentWeight: Double { store.maxWeight(for: exercise) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(exercise.name).font(.largeTitle.bold())
                    Text("\(exercise.target.title) • \(exercise.sets.count) serie")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    DetailMetric(title: "Massimo", value: "\(format(currentWeight)) kg")
                    DetailMetric(title: "Aggiornamenti", value: "\(history.count)")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Andamento peso").font(.headline)
                    Text(history.isEmpty ? "Il punto mostra il peso attuale. I prossimi cambiamenti creeranno lo storico." : "Ogni nuovo peso confermato aggiunge un punto al grafico.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Chart(chartPoints) { item in
                        LineMark(
                            x: .value("Data", item.date),
                            y: .value("Kg", item.weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(accentColor)

                        PointMark(
                            x: .value("Data", item.date),
                            y: .value("Kg", item.weight)
                        )
                        .foregroundStyle(accentColor)
                    }
                    .chartYScale(domain: 0...300)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 50, 100, 150, 200, 250, 300]) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel { Text("\(value.as(Int.self) ?? 0) kg") }
                        }
                    }
                    .frame(height: 300)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))

                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Storico").font(.headline)
                        ForEach(history.reversed()) { log in
                            HStack {
                                Text(log.date.formatted(date: .abbreviated, time: .shortened))
                                Spacer()
                                Text("\(format(log.weight)) kg").bold()
                            }
                            Divider()
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
                }
            }
            .padding()
        }
        .navigationTitle("Progressi")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chartPoints: [WeightLog] {
        if !history.isEmpty { return history }
        guard currentWeight > 0 else { return [] }
        return [WeightLog(date: Date(), weight: currentWeight)]
    }

    private func format(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".0", with: "")
    }
}

struct DetailMetric: View {
    @Environment(\.gymAccentColor) private var accentColor
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - AGGIUNGI

struct AddExerciseView: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    let onAdded: () -> Void
    @State private var name = ""
    @State private var reps = "8-10"
    @State private var sets = 3
    @State private var recovery = "2:00"
    @State private var weights: [String] = ["20", "20", "20"]
    @State private var perSetReps: [String] = ["8", "8", "8"]
    @State private var backOffEnabled = false
    @State private var selectedMuscle: MuscleTarget = .fullBody
    @FocusState private var field: Bool

    private var needsMuscleSelection: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !ExerciseRecognizer.isKnownExercise(trimmed)
    }

    var body: some View {
        Form {
            Section("Giorno") {
                Picker("Giorno", selection: $store.selectedDay) {
                    ForEach(store.days, id: \.self) { Text($0) }
                }
                if store.scheduleMode == .trainingDays {
                    Button { store.addTrainingDay() } label: {
                        Label("Aggiungi nuovo giorno", systemImage: "plus.circle.fill")
                    }
                    .disabled(store.trainingDayCount >= 7)
                }
            }
            Section("Esercizio") {
                TextField("Nome", text: $name).focused($field)
                if store.repetitionMode == .general {
                    TextField("Ripetizioni generali (es. 8-10)", text: $reps)
                } else {
                    Text("Ripetizioni per serie").font(.caption.bold())
                    ForEach(0..<sets, id: \.self) { i in
                        HStack {
                            Text("Serie \(i + 1)")
                            Spacer()
                            TextField("8", text: Binding(
                                get: { perSetReps.indices.contains(i) ? perSetReps[i] : "8" },
                                set: { if perSetReps.indices.contains(i) { perSetReps[i] = $0.filter(\.isNumber) } }
                            ))
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        }
                    }
                }
                Stepper("Serie normali: \(sets)", value: $sets, in: 1...20)
                    .onChange(of: sets) { _, newValue in
                        if weights.count < newValue { weights += Array(repeating: "20", count: newValue - weights.count) }
                        else { weights = Array(weights.prefix(newValue)) }
                        if perSetReps.count < newValue { perSetReps += Array(repeating: reps.isEmpty ? "8" : reps.filter(\.isNumber), count: newValue - perSetReps.count) }
                        else { perSetReps = Array(perSetReps.prefix(newValue)) }
                    }
                Toggle("Aggiungi back-off −20%", isOn: $backOffEnabled).tint(accentColor)
                if needsMuscleSelection {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Esercizio non presente nel registro").font(.caption.bold())
                        Picker("Muscolo principale", selection: $selectedMuscle) { ForEach(MuscleTarget.allCases, id: \.self) { Text($0.title).tag($0) } }
                    }
                }
                TextField("Recupero (es. 2:00)", text: $recovery)
            }
            Section("Kg per serie normale") {
                ForEach(0..<weights.count, id: \.self) { i in
                    TextField("Serie \(i + 1)", text: $weights[i]).keyboardType(.decimalPad)
                }
            }
            Button("Aggiungi alla scheda") {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else { return }
                let ws = weights.map { Double($0.replacingOccurrences(of: ",", with: ".")) ?? 20 }
                let prs = perSetReps.map { $0.isEmpty ? "8" : $0 }
                store.addExercise(day: store.selectedDay, name: trimmedName, reps: reps, weights: ws, recovery: recovery,
                                  backOffEnabled: backOffEnabled, manualTarget: needsMuscleSelection ? selectedMuscle : nil,
                                  perSetReps: store.repetitionMode == .perSet ? prs : nil)
                field = false; onAdded()
                name = ""; reps = "8-10"; sets = 3; recovery = "2:00"
                weights = ["20", "20", "20"]; perSetReps = ["8", "8", "8"]
                backOffEnabled = false; selectedMuscle = .fullBody
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fine") { field = false } }
        }
        .navigationTitle("Aggiungi esercizio")
    }
}

// MARK: - IMPOSTAZIONI

struct SettingsView: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    @Binding var darkMode: Bool
    @Binding var accentColorName: String
    @AppStorage("gymapp.showMuscleMap") private var showMuscleMap = true

    var body: some View {
        Form {
            Section("Aspetto") {
                Toggle("Tema scuro", isOn: $darkMode)
                Picker("Colore principale", selection: $accentColorName) {
                    ForEach(AccentColorOption.allCases) { option in
                        HStack { Circle().fill(option.color).frame(width: 12, height: 12); Text(option.title) }.tag(option.rawValue)
                    }
                }
                Toggle("Mostra immagine muscolare", isOn: $showMuscleMap)
            }

            Section("Organizzazione allenamenti") {
                Picker("Calendario", selection: Binding(
                    get: { store.scheduleMode },
                    set: { store.setScheduleMode($0) }
                )) {
                    ForEach(ScheduleMode.allCases) { Text($0.title).tag($0) }
                }
                if store.scheduleMode == .trainingDays {
                    Stepper("Giorni della scheda: \(store.trainingDayCount)", value: Binding(
                        get: { store.trainingDayCount },
                        set: { store.setTrainingDayCount($0) }
                    ), in: 1...7)

                    Text("Calendario automatico")
                        .font(.subheadline.bold())
                    Text("Associa ogni GIORNO all'effettivo giorno della settimana. L'app aggiorna automaticamente l'allenamento quando cambia la data, anche a mezzanotte.")
                        .font(.caption).foregroundStyle(.secondary)

                    ForEach(store.days, id: \.self) { day in
                        Picker(day, selection: Binding<String?>(
                            get: { store.weekdayForTrainingDay(day) },
                            set: { store.setTrainingDayWeekday(day, weekday: $0) }
                        )) {
                            Text("Non assegnato").tag(String?.none)
                            ForEach(store.calendarWeekdays, id: \.self) { weekday in
                                Text(weekday.capitalized).tag(String?(weekday))
                            }
                        }
                    }

                    Button { store.addTrainingDay() } label: {
                        Label("Aggiungi nuovo giorno", systemImage: "plus.circle.fill")
                    }
                    .disabled(store.trainingDayCount >= 7)

                    Text("Oggi: \(store.selectedDay)")
                        .font(.caption.bold())
                        .foregroundStyle(accentColor)
                } else {
                    Text("Sono disponibili i 7 giorni della settimana. Il calendario usa automaticamente il giorno reale dell'iPhone e aggiorna la scheda al cambio di giornata.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Che giorno è?") {
                DatePicker(
                    "Data di oggi",
                    selection: Binding(
                        get: { store.currentCalendarDate },
                        set: { store.setCalendarDate($0) }
                    ),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)

                Text(store.currentCalendarDate.formatted(
                    Date.FormatStyle()
                        .weekday(.wide)
                        .day()
                        .month(.wide)
                        .year()
                ))
                .font(.subheadline.bold())
                .foregroundStyle(accentColor)

                Button("Imposta automaticamente la data dell'iPhone") {
                    store.setCalendarDate(Date())
                }

                Text("Il calendario si aggiorna automaticamente allo scoccare delle 00:00. Se la data è sbagliata, seleziona manualmente quella corretta: da quel momento l'app avanzerà di un giorno a ogni nuova giornata.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Ripetizioni") {
                Picker("Prescrizione", selection: Binding(
                    get: { store.repetitionMode },
                    set: { store.setRepetitionMode($0) }
                )) {
                    ForEach(RepetitionMode.allCases) { Text($0.title).tag($0) }
                }
                if store.repetitionMode == .general {
                    Text("Esempio: 3 × 8-10. Nell'esercizio vengono mostrati solo i pesi delle singole serie.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Esempio: S1 10 · S2 8 · S3 8. Ogni serie può avere una prescrizione diversa.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Dati") {
                Text("I dati vengono salvati localmente sul telefono.")
                Button("Richiedi notifiche") { RecoveryNotifications.shared.requestPermission() }
            }
        }
        .navigationTitle("Impostazioni")
    }
}

#Preview {
    ContentView().environmentObject(WorkoutStore())
}
