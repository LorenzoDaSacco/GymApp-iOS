import SwiftUI
import Charts
import PhotosUI
import PDFKit
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: WorkoutStore
    @AppStorage("gymapp.darkMode") private var darkMode = true
    @State private var showingImporter = false

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(store: store, showImporter: $showingImporter)
            }
            .tabItem { Label("Scheda", systemImage: "list.bullet.clipboard") }

            NavigationStack {
                AnalyticsView(store: store)
            }
            .tabItem { Label("Progressi", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationStack {
                AddExerciseView(store: store)
            }
            .tabItem { Label("Aggiungi", systemImage: "plus.circle") }

            NavigationStack {
                SettingsView(store: store, darkMode: $darkMode)
            }
            .tabItem { Label("Impostazioni", systemImage: "gearshape") }
        }
        .sheet(isPresented: $showingImporter) { SheetImportView(store: store) }
        .tint(.purple)
        .preferredColorScheme(darkMode ? .dark : .light)
    }
}

struct DashboardView: View {
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
                            .background(.purple.opacity(0.15), in: .circle)
                    }
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
                    .tint(.purple)

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
    @ObservedObject var store: WorkoutStore
    let exercise: Exercise
    @State private var editing = false
    @State private var weightText: [UUID: String] = [:]
    @State private var repsText: [UUID: String] = [:]
    @FocusState private var focused: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name).font(.headline)
                    Text(exercise.group).font(.caption.bold()).foregroundStyle(.purple)
                    Text(exercise.focus).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(editing ? "Fine" : "Modifica") { editing.toggle() }
            }

            HStack {
                Text("Recupero").font(.caption.bold())
                TextField("2:00", text: Binding(
                    get: { exercise.recovery },
                    set: { store.setRecovery($0, exerciseID: exercise.id) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .disabled(!editing)
                Spacer()
                Text(exercise.target.title)
                    .font(.caption2)
                    .padding(7)
                    .background(.purple.opacity(0.12), in: Capsule())
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
                Button("+ Serie") { store.addSet(to: exercise.id) }.buttonStyle(.bordered)
                Button("− Serie") { store.removeSet(from: exercise.id) }.buttonStyle(.bordered)
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
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.purple.opacity(0.15)))
    }
}

struct SetRow: View {
    @ObservedObject var store: WorkoutStore
    let exercise: Exercise
    let index: Int
    let set: WorkoutSet
    let editing: Bool
    @Binding var weightText: [UUID: String]
    @Binding var repsText: [UUID: String]
    var focused: FocusState<UUID?>.Binding

    var body: some View {
        HStack(spacing: 10) {
            Text("S\(index + 1)").font(.caption.bold()).frame(width: 30)
            TextField(set.reps, text: Binding(
                get: { repsText[set.id] ?? set.reps },
                set: { repsText[set.id] = $0; store.setReps($0, exerciseID: exercise.id, setID: set.id) }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 75)
            .disabled(!editing)

            TextField("kg", text: Binding(
                get: {
                    weightText[set.id] ?? (set.weight == 0 ? "" : String(format: "%.1f", set.weight).replacingOccurrences(of: ".0", with: ""))
                },
                set: { weightText[set.id] = $0 }
            ))
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .frame(width: 75)
            .focused(focused, equals: set.id)
            .disabled(!editing)
            .onSubmit { commitWeight() }
            .onChange(of: focused.wrappedValue) { if $0 == nil { commitWeight() } }

            Button { store.toggle(exercise.id, setID: set.id) } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fine") { focused.wrappedValue = nil }
            }
        }
    }

    private func commitWeight() {
        let raw = weightText[set.id] ?? ""
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else {
            if raw.isEmpty { store.updateWeight(0, exerciseID: exercise.id, setID: set.id, saveHistory: false) }
            return
        }
        store.updateWeight(value, exerciseID: exercise.id, setID: set.id)
        weightText[set.id] = String(format: "%.1f", value).replacingOccurrences(of: ".0", with: "")
    }
}

// MARK: - PROGRESSI

struct AnalyticsView: View {
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
                        Text(workoutName(for: day)).font(.caption.bold()).foregroundStyle(.purple)
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
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.headline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DayProgressView: View {
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
                                .foregroundStyle(.purple)
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
                        .foregroundStyle(.purple)

                        PointMark(
                            x: .value("Data", item.date),
                            y: .value("Kg", item.weight)
                        )
                        .foregroundStyle(.purple)
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
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - AGGIUNGI

struct AddExerciseView: View {
    @ObservedObject var store: WorkoutStore
    @State private var name = ""
    @State private var reps = "8-10"
    @State private var sets = 3
    @State private var recovery = "2:00"
    @State private var weights: [String] = ["20", "20", "20"]
    @FocusState private var field: Bool

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
                Stepper("Serie: \(sets)", value: $sets, in: 1...20)
                    .onChange(of: sets) { newValue in
                        if weights.count < newValue {
                            weights += Array(repeating: "20", count: newValue - weights.count)
                        } else {
                            weights = Array(weights.prefix(newValue))
                        }
                    }
                TextField("Recupero (es. 2:00)", text: $recovery)
            }
            Section("Kg per serie") {
                ForEach(0..<weights.count, id: \.self) { i in
                    TextField("Serie \(i + 1)", text: $weights[i]).keyboardType(.decimalPad)
                }
            }
            Button("Aggiungi alla scheda") {
                let ws = weights.map { Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 }
                store.addExercise(day: store.selectedDay, name: name, reps: reps, weights: ws, recovery: recovery)
                name = ""
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
}

// MARK: - IMPORTA SCHEDA

struct SheetImportView: View {
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
    @ObservedObject var store: WorkoutStore
    @Binding var darkMode: Bool

    var body: some View {
        Form {
            Section("Aspetto") {
                Toggle("Tema scuro", isOn: $darkMode)
                HStack {
                    Text("Tema attuale")
                    Spacer()
                    Text(darkMode ? "Scuro" : "Chiaro")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Dati") {
                Text("I dati vengono salvati localmente sul telefono.")
                Button("Richiedi notifiche") { RecoveryNotifications.shared.requestPermission() }
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
    }
}

#Preview {
    ContentView().environmentObject(WorkoutStore())
}
