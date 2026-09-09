
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: WorkoutStore
    @AppStorage("gymapp.dark") private var darkMode = true
    @State private var showAdd = false
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {

    NavigationStack {
        dashboard
    }
    .tabItem {
        Label("Allenamento", systemImage: "dumbbell.fill")
    }
    .tag(0)

    NavigationStack {
        AddExerciseView(selectedTab: $selectedTab)
    }
    .tabItem {
        Label("Aggiungi", systemImage: "plus.circle.fill")
    }
    .tag(1)

    NavigationStack {
        SettingsView(
            darkMode: $darkMode,
            selectedTab: $selectedTab
        )
    }
    .tabItem {
        Label("Impostazioni", systemImage: "gearshape.fill")
    }
    .tag(2)
}

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("GYM TRACKER PRO").font(.caption.bold()).tracking(2).foregroundStyle(.red)
                    Text("Costruisci la tua\nversione migliore.")
                        .font(.system(size: 31, weight: .black))
                    Text("Allenamenti, progressi e muscoli sotto controllo.")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Picker("Giorno", selection: $store.selectedDay) {
                    ForEach(store.days, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                HStack(spacing: 10) {
                    Metric(title:"SERIE", value:"\(store.totalSets)", icon:"list.bullet")
                    Metric(title:"COMPLETATE", value:"\(store.completedSets)", icon:"checkmark.circle")
                    Metric(title:"ESERCIZI", value:"\(store.dayExercises.count)", icon:"figure.strengthtraining.traditional")
                }
                .padding(.horizontal)

                HStack {
                    Text("Progressione giornata").font(.headline)
                    Spacer()
                    Text("\(store.completedSets)/\(store.totalSets)")
                        .font(.caption.bold()).foregroundStyle(.red)
                }.padding(.horizontal)

                ProgressView(value: store.totalSets == 0 ? 0 : Double(store.completedSets)/Double(store.totalSets))
                    .tint(.red).padding(.horizontal)

                if store.dayExercises.isEmpty {
                    ContentUnavailableView("Nessun esercizio", systemImage:"dumbbell", description:Text("Aggiungi un esercizio per iniziare."))
                } else {
                    ForEach(store.dayExercises) { ex in ExerciseCard(exercise: ex) }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(store.selectedDay)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName:"plus") }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Reset") { store.resetDay() }.font(.caption)
            }
        }
    }
}

struct Metric: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(alignment:.leading, spacing:7) {
            Image(systemName:icon).foregroundStyle(.red)
            Text(value).font(.title2.bold())
            Text(title).font(.system(size:9, weight:.bold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth:.infinity, alignment:.leading).padding(12)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius:14))
    }
}

struct ExerciseCard: View {
    @EnvironmentObject private var store: WorkoutStore
    let exercise: Exercise
    var body: some View {
        VStack(alignment:.leading, spacing:13) {
            HStack(alignment:.top) {
                VStack(alignment:.leading, spacing:5) {
                    Text(exercise.name).font(.title3.bold())
                    Text(exercise.focus).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(exercise.group)
                    .font(.system(size:10, weight:.bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal,8).padding(.vertical,5)
                    .background(.red.opacity(0.12))
                    .clipShape(Capsule())
            }

            MuscleMapView(target: exercise.target)
                .frame(height:150)
                .clipShape(RoundedRectangle(cornerRadius:12))

            ForEach(exercise.sets) { set in
                HStack {
                    Button { store.toggle(exercise.id, setID:set.id) } label: {
                        Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                            .font(.title3).foregroundStyle(set.completed ? .red : .secondary)
                    }
                    VStack(alignment:.leading) {
                        Text("Serie \(exercise.sets.firstIndex(of:set)! + 1)").font(.subheadline.bold())
                        Text("Target \(set.reps) · Recupero \(exercise.recovery)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing:4) {
                        TextField("kg", value: Binding(
                            get:{set.weight},
                            set:{store.updateWeight($0, exerciseID:exercise.id, setID:set.id)}
                        ), format:.number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width:60)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius:10))
            }

            if !exercise.notes.isEmpty {
                Label(exercise.notes, systemImage:"info.circle").font(.caption).foregroundStyle(.secondary)
            }

            Button(role:.destructive) { store.remove(exercise) } label: {
                Label("Rimuovi esercizio", systemImage:"trash")
            }.font(.caption)
        }
        .padding(15)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius:18))
        .padding(.horizontal)
    }
}

struct AddExerciseView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var day = "UPPER"
    @State private var name = ""
    @State private var reps = "8-10"
    @State private var sets = 3
    @State private var weight = 20.0

    var body: some View {
        Form {
            Section("Nuovo esercizio") {
                Picker("Giorno", selection:$day) { ForEach(store.days,id:\.self){Text($0)} }
                TextField("Nome esercizio", text:$name)
                TextField("Ripetizioni target", text:$reps)
                Stepper("Numero di serie: \(sets)", value:$sets, in:1...10)
                HStack {
                    Text("Peso iniziale")
                    Spacer()
                    TextField("kg", value:$weight, format:.number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    Text("kg")
                }
            }
            if !name.trimmingCharacters(in:.whitespaces).isEmpty {
                let r = ExerciseRecognizer.recognize(name)
                Section("Riconoscimento automatico") {
                    Text(r.group).bold()
                    Text(r.focus).foregroundStyle(.secondary)
                }
            }
            Section {
                Button {
                    guard !name.trimmingCharacters(in:.whitespaces).isEmpty else { return }
                    store.addExercise(day:day, name:name, reps:reps, numberOfSets:sets, weight:weight)
                    name = ""; dismiss()
                } label: { Label("Aggiungi esercizio", systemImage:"plus.circle.fill") }
            }
        }
        .navigationTitle("Aggiungi esercizio")
    }
}

struct SettingsView: View {
    @Binding var darkMode: Bool
    var body: some View {
        Form {
            Section("Aspetto") {
                Toggle("Tema scuro", isOn:$darkMode)
            }
            Section("Gym Tracker Pro") {
                LabeledContent("Versione", value:"iPhone nativa")
                Text("I dati degli allenamenti vengono salvati localmente sull'iPhone.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Impostazioni")
    }
}
