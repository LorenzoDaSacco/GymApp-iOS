import SwiftUI
import Charts

struct ContentView: View {

    @EnvironmentObject private var store: WorkoutStore

    @AppStorage("gymapp.dark")
    private var darkMode = true

    @State private var selectedTab = 0

    var body: some View {

        TabView(selection: $selectedTab) {

            NavigationStack {
                dashboard
            }
            .tabItem {
                Label(
                    "Allenamento",
                    systemImage: "dumbbell.fill"
                )
            }
            .tag(0)

            NavigationStack {
                ProgressView()
            }
            .tabItem {
                Label(
                    "Progressi",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            }
            .tag(1)

            NavigationStack {
                AddExerciseView(
                    selectedTab: $selectedTab
                )
            }
            .tabItem {
                Label(
                    "Aggiungi",
                    systemImage: "plus.circle.fill"
                )
            }
            .tag(2)

            NavigationStack {
                SettingsView(
                    darkMode: $darkMode,
                    selectedTab: $selectedTab
                )
            }
            .tabItem {
                Label(
                    "Impostazioni",
                    systemImage: "gearshape.fill"
                )
            }
            .tag(3)
        }
        .preferredColorScheme(
            darkMode ? .dark : .light
        )
    }

    private var dashboard: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 18
            ) {

                // SOLO IL TITOLO
                Text("GYM TRACKER PRO")
                    .font(.caption.bold())
                    .tracking(2)
                    .foregroundStyle(.red)
                    .padding(.horizontal)

                // GIORNI
                Picker(
                    "Giorno",
                    selection: $store.selectedDay
                ) {

                    ForEach(
                        store.days,
                        id: \.self
                    ) {
                        Text($0)
                            .tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // METRICHE
                HStack(spacing: 10) {

                    Metric(
                        title: "SERIE",
                        value: "\(store.totalSets)",
                        icon: "list.bullet"
                    )

                    Metric(
                        title: "COMPLETATE",
                        value: "\(store.completedSets)",
                        icon: "checkmark.circle"
                    )

                    Metric(
                        title: "ESERCIZI",
                        value: "\(store.dayExercises.count)",
                        icon: "figure.strengthtraining.traditional"
                    )
                }
                .padding(.horizontal)

                HStack {

                    Text("Progressione giornata")
                        .font(.headline)

                    Spacer()

                    Text(
                        "\(store.completedSets)/\(store.totalSets)"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                }
                .padding(.horizontal)

                ProgressView(
                    value: store.totalSets == 0
                    ? 0
                    : Double(store.completedSets)
                    / Double(store.totalSets)
                )
                .tint(.red)
                .padding(.horizontal)

                if store.dayExercises.isEmpty {

                    ContentUnavailableView(
                        "Nessun esercizio",
                        systemImage: "dumbbell",
                        description: Text(
                            "Aggiungi un esercizio per iniziare."
                        )
                    )

                } else {

                    ForEach(
                        store.dayExercises
                    ) { exercise in

                        ExerciseCard(
                            exercise: exercise
                        )
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(
            store.selectedDay
        )
        .toolbar {

            ToolbarItem(
                placement: .topBarTrailing
            ) {

                Button {

                    selectedTab = 2

                } label: {

                    Image(systemName: "plus")
                }
            }

            ToolbarItem(
                placement: .topBarLeading
            ) {

                Button("Reset") {

                    store.resetDay()
                }
                .font(.caption)
            }
        }
    }
}

// MARK: - METRIC

struct Metric: View {

    let title: String
    let value: String
    let icon: String

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 7
        ) {

            Image(systemName: icon)
                .foregroundStyle(.red)

            Text(value)
                .font(.title2.bold())

            Text(title)
                .font(
                    .system(
                        size: 9,
                        weight: .bold
                    )
                )
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(12)
        .background(
            Color.secondary.opacity(0.10)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14
            )
        )
    }
}

// MARK: - ESERCIZIO

struct ExerciseCard: View {

    @EnvironmentObject private var store: WorkoutStore

    let exercise: Exercise

    @State private var weightText: [UUID: String] = [:]

    @FocusState private var focusedSet: UUID?

    private func bindingForWeight(
        _ set: WorkoutSet
    ) -> Binding<String> {

        Binding(

            get: {

                if let value = weightText[set.id] {
                    return value
                }

                return formatWeight(
                    set.weight
                )
            },

            set: { newValue in

                weightText[set.id] = newValue
            }
        )
    }

    private func formatWeight(
        _ weight: Double
    ) -> String {

        if weight.truncatingRemainder(
            dividingBy: 1
        ) == 0 {

            return String(
                Int(weight)
            )
        }

        return String(weight)
    }

    private func commitWeight(
        _ set: WorkoutSet
    ) {

        let text =
            weightText[set.id]
            ?? formatWeight(set.weight)

        guard
            let value = Double(
                text.replacingOccurrences(
                    of: ",",
                    with: "."
                )
            )
        else {
            weightText[set.id] =
                formatWeight(set.weight)

            return
        }

        store.saveWeightHistory(
            weight: value,
            exerciseID: exercise.id,
            setID: set.id
        )

        weightText[set.id] =
            formatWeight(value)

        focusedSet = nil
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 13
        ) {

            HStack(
                alignment: .top
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(exercise.name)
                        .font(.title3.bold())

                    Text(exercise.focus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(exercise.group)
                    .font(
                        .system(
                            size: 10,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        .red.opacity(0.12)
                    )
                    .clipShape(Capsule())
            }

            // SERIE
            HStack {

                Text(
                    "\(exercise.sets.count) serie"
                )
                .font(.caption.bold())
                .foregroundStyle(.secondary)

                Spacer()

                Button {

                    store.removeSet(
                        from: exercise.id
                    )

                } label: {

                    Image(
                        systemName:
                            "minus.circle.fill"
                    )
                }

                Button {

                    store.addSet(
                        to: exercise.id
                    )

                } label: {

                    Image(
                        systemName:
                            "plus.circle.fill"
                    )
                }
            }
            .foregroundStyle(.red)

            // MAPPA MUSCOLARE
            MuscleMapView(
                target: exercise.target
            )
            .frame(
                maxWidth: .infinity
            )
            .frame(height: 180)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 12
                )
            )

            // SINGOLE SERIE
            ForEach(exercise.sets) { set in

                HStack {

                    Button {

                        store.toggle(
                            exercise.id,
                            setID: set.id
                        )

                    } label: {

                        Image(
                            systemName:
                                set.completed
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                        .font(.title3)
                        .foregroundStyle(
                            set.completed
                            ? .red
                            : .secondary
                        )
                    }

                    VStack(
                        alignment: .leading
                    ) {

                        Text(
                            "Serie \(exercise.sets.firstIndex(of: set)! + 1)"
                        )
                        .font(
                            .subheadline.bold()
                        )

                        Text(
                            "Target \(set.reps) · Recupero \(exercise.recovery)"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    HStack(spacing: 4) {

                        TextField(
                            "kg",
                            text: bindingForWeight(set)
                        )
                        .keyboardType(
                            .decimalPad
                        )
                        .multilineTextAlignment(
                            .trailing
                        )
                        .frame(width: 65)
                        .focused(
                            $focusedSet,
                            equals: set.id
                        )
                        .onSubmit {

                            commitWeight(set)
                        }
                        .toolbar {

                            ToolbarItemGroup(
                                placement:
                                    .keyboard
                            ) {

                                Spacer()

                                Button("Fine") {

                                    commitWeight(set)
                                }
                            }
                        }

                        Text("kg")
                            .foregroundStyle(
                                .secondary
                            )
                    }
                }
                .padding(10)
                .background(
                    Color.secondary.opacity(
                        0.08
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 10
                    )
                )
                .contentShape(Rectangle())
                .onTapGesture {

                    focusedSet = set.id
                }
            }

            if !exercise.notes.isEmpty {

                Label(
                    exercise.notes,
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Button(
                role: .destructive
            ) {

                store.remove(exercise)

            } label: {

                Label(
                    "Rimuovi esercizio",
                    systemImage: "trash"
                )
            }
            .font(.caption)
        }
        .padding(15)
        .background(
            Color.secondary.opacity(0.08)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
        .padding(.horizontal)
        .onTapGesture {

            focusedSet = nil
        }
    }
}

// MARK: - PROGRESSI

struct ProgressView: View {

    @EnvironmentObject private var store: WorkoutStore

    @State private var selectedExerciseID: UUID?

    private var selectedExercise: Exercise? {

        if let id = selectedExerciseID {
            return store.exercises.first {
                $0.id == id
            }
        }

        return store.exercises.first
    }

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 18
            ) {

                Text("Progressi")
                    .font(
                        .system(
                            size: 32,
                            weight: .black
                        )
                    )
                    .padding(.horizontal)

                if store.exercises.isEmpty {

                    ContentUnavailableView(
                        "Nessun dato",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text(
                            "Inizia ad allenarti per creare il tuo storico."
                        )
                    )

                } else {

                    Picker(
                        "Esercizio",
                        selection: $selectedExerciseID
                    ) {

                        ForEach(
                            store.exercises
                        ) { exercise in

                            Text(exercise.name)
                                .tag(
                                    Optional(exercise.id)
                                )
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)

                    if let exercise = selectedExercise {

                        ProgressExerciseCard(
                            exercise: exercise
                        )
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Progressi")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - CARD PROGRESSI

struct ProgressExerciseCard: View {

    let exercise: Exercise

    private var points: [WeightLog] {

        exercise.sets
            .flatMap {
                $0.history
            }
            .sorted {
                $0.date < $1.date
            }
    }

    private var currentWeight: Double {

        exercise.sets
            .map(\.weight)
            .max() ?? 0
    }

    private var firstWeight: Double? {

        points.first?.weight
    }

    private var improvement: Double {

        guard
            let first = firstWeight
        else {
            return 0
        }

        return currentWeight - first
    }

    private var daysPassed: Int {

        guard
            let firstDate = points.first?.date
        else {
            return 0
        }

        return max(
            0,
            Calendar.current.dateComponents(
                [.day],
                from: firstDate,
                to: Date()
            ).day ?? 0
        )
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 18
        ) {

            Text(exercise.name)
                .font(.title2.bold())

            HStack(spacing: 10) {

                ProgressMetric(
                    title: "ATTUALE",
                    value: "\(format(currentWeight)) kg"
                )

                ProgressMetric(
                    title: "AUMENTO",
                    value:
                        "\(improvement >= 0 ? "+" : "")\(format(improvement)) kg"
                )

                ProgressMetric(
                    title: "GIORNI",
                    value: "\(daysPassed)"
                )
            }

            if points.isEmpty {

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Image(
                        systemName:
                            "chart.line.uptrend.xyaxis"
                    )
                    .font(.largeTitle)
                    .foregroundStyle(.red)

                    Text(
                        "Nessuno storico ancora"
                    )
                    .font(.headline)

                    Text(
                        "Quando cambi un peso e premi Fine, verrà salvata la data e potrai vedere qui la progressione."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(
                    Color.secondary.opacity(
                        0.08
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14
                    )
                )

            } else {

                Chart(points) { point in

                    LineMark(
                        x: .value(
                            "Data",
                            point.date
                        ),
                        y: .value(
                            "Kg",
                            point.weight
                        )
                    )
                    .foregroundStyle(.red)

                    PointMark(
                        x: .value(
                            "Data",
                            point.date
                        ),
                        y: .value(
                            "Kg",
                            point.weight
                        )
                    )
                    .foregroundStyle(.red)
                }
                .frame(height: 260)
                .padding(.vertical)

                Text(
                    "Il grafico mostra la progressione del carico registrato nel tempo."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                Text("Storico")
                    .font(.headline)

                ForEach(
                    points.reversed()
                ) { point in

                    HStack {

                        Text(
                            point.date,
                            format: .dateTime
                                .day()
                                .month()
                                .year()
                        )

                        Spacer()

                        Text(
                            "\(format(point.weight)) kg"
                        )
                        .font(.headline)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(
            Color.secondary.opacity(0.08)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
        .padding(.horizontal)
    }

    private func format(
        _ value: Double
    ) -> String {

        if value.truncatingRemainder(
            dividingBy: 1
        ) == 0 {

            return String(
                Int(value)
            )
        }

        return String(
            format: "%.1f",
            value
        )
    }
}

struct ProgressMetric: View {

    let title: String
    let value: String

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 5
        ) {

            Text(title)
                .font(
                    .system(
                        size: 9,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    .secondary
                )

            Text(value)
                .font(
                    .headline.bold()
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(10)
        .background(
            Color.secondary.opacity(
                0.10
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12
            )
        )
    }
}

// MARK: - AGGIUNGI ESERCIZIO

struct AddExerciseView: View {

    @EnvironmentObject private var store: WorkoutStore

    @Binding var selectedTab: Int

    @State private var day = "LUNEDÌ"
    @State private var name = ""
    @State private var reps = "8-10"
    @State private var sets = 3
    @State private var weights = [
        20.0,
        20.0,
        20.0
    ]

    @FocusState private var focusedField: Bool

    var body: some View {

        Form {

            Section("Nuovo esercizio") {

                Picker(
                    "Giorno",
                    selection: $day
                ) {

                    ForEach(
                        store.days,
                        id: \.self
                    ) {

                        Text($0)
                    }
                }

                TextField(
                    "Nome esercizio",
                    text: $name
                )
                .focused(
                    $focusedField
                )

                TextField(
                    "Ripetizioni target",
                    text: $reps
                )
                .focused(
                    $focusedField
                )

                Stepper(
                    "Numero di serie: \(sets)",
                    value: $sets,
                    in: 1...10
                )
                .onChange(of: sets) {

                    while weights.count < sets {

                        weights.append(
                            weights.last ?? 20
                        )
                    }

                    while weights.count > sets {

                        weights.removeLast()
                    }
                }
            }

            Section(
                "Peso per ogni serie"
            ) {

                ForEach(
                    0..<weights.count,
                    id: \.self
                ) { index in

                    HStack {

                        Text(
                            "Serie \(index + 1)"
                        )

                        Spacer()

                        TextField(
                            "kg",
                            value: Binding(
                                get: {
                                    weights[index]
                                },
                                set: {
                                    weights[index] = $0
                                }
                            ),
                            format: .number
                        )
                        .keyboardType(
                            .decimalPad
                        )
                        .multilineTextAlignment(
                            .trailing
                        )
                        .frame(width: 70)

                        Text("kg")
                            .foregroundStyle(
                                .secondary
                            )
                    }
                }
            }

            if !name
                .trimmingCharacters(
                    in: .whitespaces
                )
                .isEmpty {

                let r =
                    ExerciseRecognizer
                    .recognize(name)

                Section(
                    "Riconoscimento automatico"
                ) {

                    Text(r.group)
                        .bold()

                    Text(r.focus)
                        .foregroundStyle(
                            .secondary
                        )
                }
            }

            Section {

                Button {

                    let cleanName =
                        name.trimmingCharacters(
                            in: .whitespaces
                        )

                    guard
                        !cleanName.isEmpty
                    else {
                        return
                    }

                    focusedField = false

                    store.addExercise(
                        day: day,
                        name: cleanName,
                        reps: reps,
                        weights: weights
                    )

                    name = ""

                    selectedTab = 0

                } label: {

                    Label(
                        "Aggiungi esercizio",
                        systemImage:
                            "plus.circle.fill"
                    )
                }
            }
        }
        .navigationTitle(
            "Aggiungi esercizio"
        )
        .toolbar {

            ToolbarItem(
                placement: .topBarLeading
            ) {

                Button {

                    focusedField = false
                    selectedTab = 0

                } label: {

                    Label(
                        "Scheda",
                        systemImage:
                            "chevron.left"
                    )
                }
            }

            ToolbarItemGroup(
                placement: .keyboard
            ) {

                Spacer()

                Button("Fine") {

                    focusedField = false
                }
            }
        }
    }
}

// MARK: - IMPOSTAZIONI

struct SettingsView: View {

    @Binding var darkMode: Bool
    @Binding var selectedTab: Int

    var body: some View {

        Form {

            Section("Aspetto") {

                Toggle(
                    "Tema scuro",
                    isOn: $darkMode
                )
            }

            Section("Gym Tracker Pro") {

                LabeledContent(
                    "Versione",
                    value: "iPhone nativa"
                )

                Text(
                    "I dati degli allenamenti vengono salvati localmente sull'iPhone."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .navigationTitle(
            "Impostazioni"
        )
        .toolbar {

            ToolbarItem(
                placement: .topBarLeading
            ) {

                Button {

                    selectedTab = 0

                } label: {

                    Label(
                        "Scheda",
                        systemImage:
                            "chevron.left"
                    )
                }
            }
        }
    }
}
