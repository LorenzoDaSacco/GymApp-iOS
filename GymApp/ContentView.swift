import SwiftUI
import Charts
import PhotosUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

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
    @AppStorage("gymapp.darkMode") private var darkMode = true
    @AppStorage("gymapp.accentColor") private var accentColorName = AccentColorOption.purple.rawValue
    @State private var showingImporter = false
    @State private var selectedTab = 0

    private var accentColor: Color { AccentColorOption(rawValue: accentColorName)?.color ?? .purple }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(store: store, showImporter: $showingImporter)
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
        .sheet(isPresented: $showingImporter) { SheetImportView(store: store) }
        .tint(accentColor)
        .environment(\.gymAccentColor, accentColor)
        .preferredColorScheme(darkMode ? .dark : .light)
    }
}

struct DashboardView: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    @Binding var showImporter: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("GYM TRACKER PRO")
                        .font(.system(size: 26, weight: .black))
                    Spacer()
                    Button { showImporter = true } label: {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .padding(10)
                            .background(accentColor.opacity(0.15), in: .circle)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("GIORNO")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.days, id: \.self) { day in
                                Button {
                                    focusedDaySelection(day)
                                } label: {
                                    Text(day.prefix(3))
                                        .font(.caption.bold())
                                        .frame(minWidth: 54)
                                        .padding(.vertical, 11)
                                        .background(
                                            store.selectedDay == day
                                                ? accentColor
                                                : accentColor.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 13)
                                        )
                                        .foregroundStyle(
                                            store.selectedDay == day ? Color.white : Color.primary
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("SETTIMANA")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    WeeklyOverviewCard(store: store) { day in
                        focusedDaySelection(day)
                    }
                }

                HStack(spacing: 12) {
                    Metric(title: "Esercizi", value: "\(store.dayExercises.count)", icon: "figure.strengthtraining.traditional")
                    Metric(title: "Serie", value: "\(store.totalSets)", icon: "square.stack.3d.up")
                    Metric(title: "Completate", value: "\(store.completedSets)", icon: "checkmark.circle")
                }

                SwiftUI.ProgressView(value: store.totalSets == 0 ? 0 : Double(store.completedSets) / Double(store.totalSets))
                    .tint(accentColor)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("OGGI")
                            .font(.caption.bold())
                            .foregroundStyle(accentColor)
                        Text(store.completedSets == 0
                             ? "Pronto per iniziare"
                             : "\(store.completedSets) di \(store.totalSets) serie completate")
                            .font(.subheadline.bold())
                    }
                    Spacer()
                    Image(systemName: store.totalSets > 0 && store.completedSets == store.totalSets
                          ? "checkmark.seal.fill"
                          : "bolt.fill")
                        .font(.title3)
                        .foregroundStyle(accentColor)
                }
                .padding(14)
                .background(accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))

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
        .onAppear { store.prepareDayForToday(store.selectedDay) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") { store.resetDay() }
            }
        }
    }

    private func focusedDaySelection(_ day: String) {
        store.selectedDay = day
        store.prepareDayForToday(day)
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
    @State private var weightText: [UUID: String] = [:]
    @State private var repsText: [UUID: String] = [:]
    @State private var showingDeleteConfirmation = false
    @FocusState private var focused: UUID?

    private var previousSession: ExerciseSession? {
        store.previousSession(for: exercise)
    }

    private var performance: PerformanceComparison? {
        store.performance(for: exercise)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name).font(.headline)
                    Text(exercise.group).font(.caption.bold()).foregroundStyle(accentColor)
                    Text(exercise.focus).font(.caption).foregroundStyle(.secondary)
                    Text("Scheda: \(exercise.sets.filter { !$0.isBackOff }.count) × \(exercise.targetReps)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(editing ? "Fine" : "Modifica") {
                    commitPendingFields()
                    focused = nil
                    editing.toggle()
                }
            }

            if let previousSession {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("ULTIMA VOLTA")
                            .font(.caption.bold())
                            .foregroundStyle(accentColor)
                        Spacer()
                        Text(previousSession.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(previousSession.sets) { previousSet in
                        HStack {
                            Text("S\(previousSet.setIndex + 1)")
                                .font(.caption.bold())
                                .frame(width: 28, alignment: .leading)
                            Text("\(formatWeight(previousSet.weight)) kg")
                                .font(.caption.bold())
                            Text("×")
                                .foregroundStyle(.secondary)
                            Text("\(previousSet.reps)")
                                .font(.caption.bold())
                            if previousSet.isBackOff {
                                Text("BACK-OFF")
                                    .font(.caption2.bold())
                                    .foregroundStyle(accentColor)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(11)
                .background(accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }

            if let performance {
                PerformanceBadge(comparison: performance, accentColor: accentColor)
            }

            RecoveryTimerSection(
                store: store,
                exercise: exercise,
                editing: editing,
                accentColor: accentColor
            )

            if editing {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
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
                        Text("Ultima serie = 80% della serie precedente")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(accentColor)
            }

            HStack {
                Text("SERIE")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("PESO")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("REPS")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("✓")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                SetRow(
                    store: store,
                    exercise: exercise,
                    index: index,
                    set: set,
                    editing: editing,
                    weightText: $weightText,
                    repsText: $repsText,
                    focused: $focused
                )
            }

            HStack {
                Button("+ Serie") {
                    commitPendingFields()
                    focused = nil
                    store.addSet(to: exercise.id)
                }
                .buttonStyle(.bordered)

                Button("− Serie") {
                    focused = nil
                    store.removeSet(from: exercise.id)
                }
                .buttonStyle(.bordered)

                Spacer()
                Text("\(exercise.sets.count) serie")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            MuscleMapView(target: exercise.target)
                .frame(height: 185)
                .clipShape(RoundedRectangle(cornerRadius: 18))
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

    private func commitPendingFields() {
        for currentSet in exercise.sets where !currentSet.isBackOff {
            if let raw = weightText[currentSet.id],
               let value = Double(raw.replacingOccurrences(of: ",", with: ".")) {
                store.updateWeight(value, exerciseID: exercise.id, setID: currentSet.id)
            }
        }

        for currentSet in exercise.sets {
            if let value = repsText[currentSet.id], value != currentSet.reps {
                store.setReps(value, exerciseID: exercise.id, setID: currentSet.id)
            }
        }
    }

    private func formatWeight(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".0", with: "")
    }
}

struct PerformanceBadge: View {
    let comparison: PerformanceComparison
    let accentColor: Color

    var body: some View {
        HStack(spacing: 9) {
            Text(comparison.status.symbol)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(comparison.status.title)
                    .font(.caption.bold())
                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(11)
        .background(accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private var detailText: String {
        let percentage = abs(comparison.volumeDeltaRatio * 100)
        switch comparison.status {
        case .progress:
            return "Performance complessiva +\(format(percentage))% rispetto all'ultima sessione."
        case .maintain:
            return "Performance sostanzialmente stabile rispetto all'ultima sessione."
        case .decline:
            return "Performance complessiva −\(format(percentage))% rispetto all'ultima sessione."
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.0f", value)
    }
}

struct RecoveryTimerSection: View {
    @ObservedObject var store: WorkoutStore
    let exercise: Exercise
    let editing: Bool
    let accentColor: Color
    @State private var recoveryText: String = ""
    @FocusState private var recoveryFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text("Recupero")
                    .font(.caption.bold())

                TextField("2:00", text: $recoveryText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .focused($recoveryFocused)
                    .disabled(!editing)
                    .onAppear { recoveryText = exercise.recovery }
                    .onChange(of: recoveryFocused) { isFocused in
                        if !isFocused { commitRecovery() }
                    }
                    .onChange(of: exercise.recovery) { newValue in
                        if !recoveryFocused { recoveryText = newValue }
                    }

                Spacer()

                Text(exercise.target.title)
                    .font(.caption2)
                    .padding(7)
                    .background(accentColor.opacity(0.12), in: Capsule())
            }

            if let setID = activeTimerSetID {
                RecoveryCountdownView(
                    setID: setID,
                    duration: RecoveryNotifications.shared.duration(
                        for: setID,
                        fallback: RecoveryNotifications.seconds(from: exercise.recovery) ?? 120
                    ),
                    exerciseName: exercise.name,
                    recoveryText: exercise.recovery.isEmpty ? "2:00" : exercise.recovery,
                    accentColor: accentColor
                )
            }
        }
    }

    private func commitRecovery() {
        let value = recoveryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value != exercise.recovery else { return }
        store.setRecovery(value, exerciseID: exercise.id)
    }

    private var activeTimerSetID: UUID? {
        exercise.sets
            .compactMap { set -> (UUID, TimeInterval)? in
                guard set.completed,
                      let remaining = RecoveryNotifications.shared.remaining(for: set.id),
                      remaining > 0 else { return nil }
                return (set.id, remaining)
            }
            .max(by: { $0.1 < $1.1 })?.0
    }
}

struct RecoveryCountdownView: View {
    let setID: UUID
    let duration: TimeInterval
    let exerciseName: String
    let recoveryText: String
    let accentColor: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = RecoveryNotifications.shared.remaining(for: setID, now: context.date) ?? 0
            let paused = RecoveryNotifications.shared.isPaused(for: setID)
            let progress = duration > 0 ? min(1, max(0, remaining / duration)) : 0

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(remaining > 0 ? formattedTime(remaining) : "PRONTO")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(remaining > 0 ? .primary : accentColor)
                    Spacer()
                    Text(paused ? "In pausa" : (remaining > 0 ? "Tempo restante" : "Puoi ripartire"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress, total: 1)
                    .tint(accentColor)
                    .scaleEffect(x: 1, y: 1.35, anchor: .center)

                HStack(spacing: 7) {
                    Button("−15") {
                        _ = RecoveryNotifications.shared.adjust(
                            for: setID,
                            seconds: -15,
                            exerciseName: exerciseName,
                            recoveryText: recoveryText
                        )
                    }
                    .buttonStyle(.bordered)

                    Button(paused ? "Riprendi" : "Pausa") {
                        if paused {
                            _ = RecoveryNotifications.shared.resume(
                                for: setID,
                                exerciseName: exerciseName,
                                recoveryText: recoveryText
                            )
                        } else {
                            RecoveryNotifications.shared.pause(for: setID)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("+15") {
                        _ = RecoveryNotifications.shared.adjust(
                            for: setID,
                            seconds: 15,
                            exerciseName: exerciseName,
                            recoveryText: recoveryText
                        )
                    }
                    .buttonStyle(.bordered)

                    Button("Salta") {
                        RecoveryNotifications.shared.skip(for: setID)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
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
    @Binding var weightText: [UUID: String]
    @Binding var repsText: [UUID: String]
    var focused: FocusState<UUID?>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Text("S\(index + 1)")
                .font(.caption.bold())
                .frame(width: 30, alignment: .leading)

            if set.isBackOff {
                Text(format(store.backOffWeight(exerciseID: exercise.id)))
                    .font(.body.bold())
                    .frame(width: 72, alignment: .trailing)
                    .padding(.vertical, 9)
                    .background(accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                Text("kg")
                    .font(.caption.bold())
                    .foregroundStyle(accentColor)
            } else {
                TextField("kg", text: Binding(
                    get: {
                        weightText[set.id] ?? (set.weight == 0 ? "" : format(set.weight))
                    },
                    set: { value in
                        weightText[set.id] = sanitizeWeightInput(value)
                    }
                ))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)
                .focused(focused, equals: set.id)
                .disabled(!editing)
                .onSubmit { commitWeight() }
                .onChange(of: focused.wrappedValue) { newFocus in
                    if newFocus == nil { commitWeight() }
                }
                Text("kg")
                    .font(.caption.bold())
                    .foregroundStyle(accentColor)
                    .frame(width: 20, alignment: .leading)
            }

            TextField(exercise.targetReps, text: Binding(
                get: { repsText[set.id] ?? set.reps },
                set: { repsText[set.id] = $0.filter(\.isNumber).prefix(3).description }
            ))
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            .frame(width: 65)
            .focused(focused, equals: set.id)
            .disabled(!editing)
            .onChange(of: focused.wrappedValue) { newFocus in
                if newFocus == nil { commitReps() }
            }

            Button(action: completeSet) {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(set.completed ? accentColor : .secondary)
            .disabled(!canComplete)

            if set.isBackOff {
                Text("BACK-OFF")
                    .font(.caption2.bold())
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fine") { focused.wrappedValue = nil }
            }
        }
    }

    private var canComplete: Bool {
        if set.completed { return true }
        let reps = repsText[set.id] ?? set.reps
        let weight = weightText[set.id] ?? format(set.weight)
        return (Int(reps) ?? 0) > 0 && Double(weight.replacingOccurrences(of: ",", with: ".")) != nil
    }

    private func completeSet() {
        commitWeight()
        commitReps()
        guard !set.completed else {
            store.toggle(exercise.id, setID: set.id)
            focused.wrappedValue = nil
            return
        }
        let reps = repsText[set.id] ?? set.reps
        guard (Int(reps) ?? 0) > 0 else { return }
        store.toggle(exercise.id, setID: set.id)
        focused.wrappedValue = nil
    }

    private func sanitizeWeightInput(_ value: String) -> String {
        let normalized = value.replacingOccurrences(of: ",", with: ".")
        var result = ""
        var hasDot = false
        for character in normalized {
            if character.isNumber {
                result.append(character)
            } else if character == "." && !hasDot {
                hasDot = true
                result.append(character)
            }
        }
        // Il campo del peso non può diventare vuoto: quando l'utente seleziona
        // tutto e cancella, manteniamo l'ultimo valore valido.
        if result.isEmpty {
            return weightText[set.id] ?? (set.weight == 0 ? "0" : format(set.weight))
        }
        return result
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".0", with: "")
    }

    private func commitReps() {
        let value = repsText[set.id] ?? set.reps
        if value != set.reps {
            store.setReps(value, exerciseID: exercise.id, setID: set.id)
        }
    }

    private func commitWeight() {
        guard !set.isBackOff else { return }
        let raw = weightText[set.id] ?? (set.weight == 0 ? "0" : format(set.weight))
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value >= 0 else { return }
        store.updateWeight(value, exerciseID: exercise.id, setID: set.id)
        weightText[set.id] = format(value)
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
                Text("Settimana reale da lunedì a domenica, serie completate e storico degli allenamenti.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                WeeklyHistorySection(store: store)

                MuscleVolumeSummary(store: store)

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


struct WeeklyOverviewCard: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    let action: (String) -> Void

    private var week: WorkoutWeekSummary { store.currentWeekSummary() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.weekTitle())
                        .font(.headline.bold())
                    Text("Lunedì → Domenica")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(week.completedSets)/\(week.totalSets)")
                        .font(.headline.bold())
                    Text("serie")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            SwiftUI.ProgressView(value: week.progress)
                .tint(accentColor)

            HStack(spacing: 6) {
                ForEach(week.days) { day in
                    Button { action(day.day) } label: {
                        VStack(spacing: 5) {
                            Text(day.day.prefix(3))
                                .font(.caption2.bold())
                            Text(day.date.formatted(.dateTime.day()))
                                .font(.headline.bold())
                            Text(day.status.symbol)
                                .font(.caption.bold())
                            if day.totalSets > 0 {
                                Text("\(day.completedSets)/\(day.totalSets)")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("-")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(background(for: day), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                Label("\(week.workoutDays) allenamenti", systemImage: "dumbbell.fill")
                Spacer()
                Label("\(week.completedWorkoutDays) completati", systemImage: "checkmark.seal.fill")
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(accentColor.opacity(0.12)))
    }

    private func background(for day: WorkoutDaySummary) -> Color {
        switch day.status {
        case .rest:
            return Color.secondary.opacity(0.07)
        case .completed:
            return accentColor.opacity(0.18)
        case .inProgress:
            return accentColor.opacity(0.10)
        case .notStarted:
            return accentColor.opacity(0.05)
        }
    }
}

struct WeeklyHistorySection: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    @State private var expandedWeekStart: Date?

    private var weeks: [WorkoutWeekSummary] { store.historicalWeekSummaries() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STORICO SETTIMANALE")
                .font(.caption.bold())
                .foregroundStyle(accentColor)

            ForEach(Array(weeks.enumerated()), id: \.element.startDate) { index, week in
                let isCurrent = Calendar.current.isDate(week.startDate, equalTo: store.startOfWeek(), toGranularity: .day)
                VStack(alignment: .leading, spacing: 9) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedWeekStart = expandedWeekStart == week.startDate ? nil : week.startDate
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(weekLabel(week))
                                    .font(.headline.bold())
                                Text("\(week.workoutDays) allenamenti • \(week.completedSets)/\(week.totalSets) serie")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isCurrent {
                                Text("ATTUALE")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(accentColor)
                            }
                            Image(systemName: expandedWeekStart == week.startDate ? "chevron.up" : "chevron.down")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    SwiftUI.ProgressView(value: week.progress)
                        .tint(accentColor)

                    if expandedWeekStart == week.startDate {
                        ForEach(week.days) { day in
                            HStack(spacing: 9) {
                                Text(day.day.prefix(3))
                                    .font(.caption.bold())
                                    .frame(width: 34, alignment: .leading)
                                Text(day.date.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if day.status == .rest {
                                    Text("RIPOSO")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(day.completedSets)/\(day.totalSets)")
                                        .font(.caption.bold())
                                    Text(day.status.title)
                                        .font(.caption2.bold())
                                        .foregroundStyle(day.status == .completed ? accentColor : .secondary)
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func weekLabel(_ week: WorkoutWeekSummary) -> String {
        let first = week.startDate.formatted(.dateTime.day().month(.wide))
        let last = week.endDate.formatted(.dateTime.day().month(.wide))
        return "\(first) – \(last)".uppercased()
    }
}

struct MuscleVolumeSummary: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore

    private var targets: [MuscleTarget] {
        MuscleTarget.allCases.filter { target in
            store.exercises.contains { $0.target == target && !$0.sessions.isEmpty }
        }
    }

    var body: some View {
        if !targets.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Volume ultimi 7 giorni").font(.headline)
                Text("Peso × ripetizioni delle serie completate. Serve solo a monitorare l'allenamento.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(targets, id: \.self) { target in
                    HStack {
                        Text(target.title)
                            .font(.caption.bold())
                        Spacer()
                        Text("\(format(store.weeklyVolume(for: target))) kg")
                            .font(.caption.bold())
                            .foregroundStyle(accentColor)
                    }
                }
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.0f", value)
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

    private var sessions: [ExerciseSession] { store.sessions(for: exercise) }
    private var weightHistory: [WeightLog] { store.history(for: exercise) }
    private var currentWeight: Double { store.maxWeight(for: exercise) }
    private var bestSession: ExerciseSession? { sessions.max(by: { $0.volume < $1.volume }) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(exercise.name).font(.largeTitle.bold())
                    Text("\(exercise.target.title) • \(exercise.sets.filter { !$0.isBackOff }.count) serie • Scheda \(exercise.targetReps)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    DetailMetric(title: "Massimo", value: "\(format(currentWeight)) kg")
                    DetailMetric(title: "Sessioni", value: "\(sessions.count)")
                    DetailMetric(title: "Volume totale", value: "\(format(store.totalVolume(for: exercise))) kg")
                }

                if let previous = sessions.dropLast().last,
                   let current = sessions.last {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Confronto ultima sessione")
                                .font(.headline)
                            Text("\(current.date.formatted(date: .abbreviated, time: .omitted)) vs \(previous.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Volume: \(format(previous.volume)) kg → \(format(current.volume)) kg")
                                .font(.subheadline.bold())
                        }
                        Spacer()
                    }
                    .padding()
                    .background(accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                }

                if !sessions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Volume nel tempo").font(.headline)
                        Chart(sessions) { session in
                            LineMark(
                                x: .value("Data", session.date),
                                y: .value("Volume", session.volume)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(accentColor)

                            PointMark(
                                x: .value("Data", session.date),
                                y: .value("Volume", session.volume)
                            )
                            .foregroundStyle(accentColor)
                        }
                        .frame(height: 230)

                        Text("Volume = peso × ripetizioni delle serie completate. È un indicatore di monitoraggio, non una misura fisiologica.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
                }

                if let bestSession {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Miglior sessione per volume").font(.headline)
                        Text(bestSession.date.formatted(date: .complete, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(bestSession.sets) { set in
                            HStack {
                                Text("S\(set.setIndex + 1)").font(.caption.bold()).frame(width: 30, alignment: .leading)
                                Text("\(format(set.weight)) kg × \(set.reps)").font(.subheadline.bold())
                                Spacer()
                                Text("\(format(set.volume))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                        HStack {
                            Text("Volume")
                            Spacer()
                            Text("\(format(bestSession.volume)) kg").bold()
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
                }

                if !sessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Storico sessioni").font(.headline)
                        ForEach(sessions.reversed()) { session in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text("\(format(session.volume)) kg volume")
                                        .font(.caption.bold())
                                        .foregroundStyle(accentColor)
                                }

                                ForEach(session.sets) { set in
                                    HStack {
                                        Text("S\(set.setIndex + 1)")
                                            .font(.caption)
                                            .frame(width: 28, alignment: .leading)
                                        Text("\(format(set.weight)) kg × \(set.reps)")
                                            .font(.caption.bold())
                                        if set.isBackOff {
                                            Text("BACK-OFF")
                                                .font(.caption2.bold())
                                                .foregroundStyle(accentColor)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                            Divider()
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
                }

                if !weightHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Storico carichi").font(.headline)
                        Chart(weightHistory) { log in
                            LineMark(
                                x: .value("Data", log.date),
                                y: .value("Kg", log.weight)
                            )
                            .foregroundStyle(accentColor)
                            PointMark(
                                x: .value("Data", log.date),
                                y: .value("Kg", log.weight)
                            )
                            .foregroundStyle(accentColor)
                        }
                        .frame(height: 220)
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

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".0", with: "")
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
            }
            Section("Esercizio") {
                TextField("Nome", text: $name).focused($field)
                TextField("Ripetizioni", text: $reps)
                Stepper("Serie normali: \(sets)", value: $sets, in: 1...20)
                    .onChange(of: sets) { newValue in
                        if weights.count < newValue {
                            weights += Array(repeating: "20", count: newValue - weights.count)
                        } else {
                            weights = Array(weights.prefix(newValue))
                        }
                    }
                Toggle("Aggiungi back-off −20%", isOn: $backOffEnabled)
                    .tint(accentColor)
                if needsMuscleSelection {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Esercizio non presente nel registro")
                            .font(.caption.bold())
                        Picker("Muscolo principale", selection: $selectedMuscle) {
                            ForEach(MuscleTarget.allCases, id: \.self) { muscle in
                                Text(muscle.title).tag(muscle)
                            }
                        }
                        Text("Scegli il muscolo principale per completare la mappa muscolare e i progressi.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                TextField("Recupero (es. 2:00)", text: $recovery)
            }
            Section("Kg per serie normale") {
                ForEach(0..<weights.count, id: \.self) { i in
                    TextField("Serie \(i + 1)", text: $weights[i]).keyboardType(.decimalPad)
                }
                if backOffEnabled {
                    let previous = Double(weights.last?.replacingOccurrences(of: ",", with: ".") ?? "") ?? 0
                    HStack {
                        Text("Back-off — ultima serie")
                        Spacer()
                        Text("\(formatWeight(previous * 0.8)) kg")
                            .foregroundStyle(accentColor)
                            .font(.body.bold())
                    }
                    Text("Il peso del back-off è automatico e non modificabile: 20% in meno rispetto all'ultima serie normale.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Aggiungi alla scheda") {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else { return }
                let ws = weights.map { Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 }
                store.addExercise(day: store.selectedDay, name: trimmedName, reps: reps, weights: ws, recovery: recovery, backOffEnabled: backOffEnabled, manualTarget: needsMuscleSelection ? selectedMuscle : nil)
                field = false
                onAdded()
                name = ""
                reps = "8-10"
                sets = 3
                recovery = "2:00"
                weights = ["20", "20", "20"]
                backOffEnabled = false
                selectedMuscle = .fullBody
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fine") { field = false }
            }
        }
        .navigationTitle("Aggiungi esercizio")
    }

    private func formatWeight(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".0", with: "")
    }
}

// MARK: - IMPORTA SCHEDA

struct SheetImportView: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    @StateObject private var importer = SheetImporter()
    @Environment(\.dismiss) private var dismiss
    @State private var camera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showingDoc = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Button("📷 Foto") { camera = true }.buttonStyle(.borderedProminent)
                        Button("📄 PDF") { showingDoc = true }.buttonStyle(.bordered)
                    }
                    Text("Oppure scegli una foto dalla galleria")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Scegli foto", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    .onChange(of: photoItem) { item in
                        if let item {
                            Task {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let img = UIImage(data: data) {
                                    importer.analyze(image: img)
                                }
                            }
                        }
                    }

                    if importer.isBusy { ProgressView("Analizzo la scheda…") }
                    if !importer.items.isEmpty {
                        Text("Controlla prima di importare").font(.headline)
                        ForEach(importer.items) { item in
                            VStack(alignment: .leading) {
                                Text(item.name).bold()
                                Text("\(item.day) · \(item.sets) serie · \(item.reps) · recupero \(item.recovery.isEmpty ? "—" : item.recovery)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("Importa") { store.addImported(item) }.buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    if !importer.recognizedText.isEmpty {
                        DisclosureGroup("Testo riconosciuto") {
                            Text(importer.recognizedText).font(.caption).textSelection(.enabled)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Importa scheda")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Chiudi") { dismiss() } }
            }
            .sheet(isPresented: $camera) { CameraPicker { image in importer.analyze(image: image) } }
            .fileImporter(isPresented: $showingDoc, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first { importer.analyze(pdfURL: url) }
            }
        }
    }
}

// MARK: - IMPOSTAZIONI

struct SettingsView: View {
    @Environment(\.gymAccentColor) private var accentColor
    @ObservedObject var store: WorkoutStore
    @Binding var darkMode: Bool
    @Binding var accentColorName: String
    @State private var exportDocument: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var backupMessage: String?

    var body: some View {
        Form {
            Section("Aspetto") {
                Toggle("Tema scuro", isOn: $darkMode)

                Picker("Colore principale", selection: $accentColorName) {
                    ForEach(AccentColorOption.allCases) { option in
                        HStack {
                            Circle()
                                .fill(option.color)
                                .frame(width: 12, height: 12)
                            Text(option.title)
                        }
                        .tag(option.rawValue)
                    }
                }

                HStack {
                    Text("Tema attuale")
                    Spacer()
                    Text(darkMode ? "Scuro" : "Chiaro")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Dati") {
                Text("I dati vengono salvati localmente sul telefono. Nessun account, cloud o server è necessario.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    guard let data = store.backupData() else {
                        backupMessage = "Impossibile creare il backup."
                        return
                    }
                    exportDocument = BackupDocument(data: data)
                    showingExporter = true
                } label: {
                    Label("Esporta backup locale", systemImage: "square.and.arrow.up")
                }

                Button {
                    showingImporter = true
                } label: {
                    Label("Importa backup locale", systemImage: "square.and.arrow.down")
                }

                Button("Richiedi notifiche") {
                    RecoveryNotifications.shared.requestPermission()
                }
            }

            Section("Settimana") {
                ForEach(store.days, id: \.self) { day in
                    HStack {
                        Text(day)
                        Spacer()
                        Text("\(store.exercises.filter { $0.day == day }.count) esercizi")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Impostazioni")
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "GymApp-Backup.json"
        ) { result in
            if case .failure = result {
                backupMessage = "Esportazione annullata o non riuscita."
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let data = try Data(contentsOf: url)
                    if store.importBackup(data: data) {
                        backupMessage = "Backup importato correttamente."
                    } else {
                        backupMessage = "Il file non contiene un backup GymApp valido."
                    }
                } catch {
                    backupMessage = "Impossibile leggere il file di backup."
                }
            case .failure:
                backupMessage = "Importazione annullata o non riuscita."
            }
        }
        .alert("Backup", isPresented: Binding(
            get: { backupMessage != nil },
            set: { if !$0 { backupMessage = nil } }
        )) {
            Button("OK") { backupMessage = nil }
        } message: {
            Text(backupMessage ?? "")
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    ContentView().environmentObject(WorkoutStore())
}
