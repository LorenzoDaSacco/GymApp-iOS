import SwiftUI
import Charts
import PhotosUI
import PDFKit
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var showingImporter = false
    var body: some View {
        TabView {
            NavigationStack { DashboardView(store: store, showImporter: $showingImporter) }.tabItem { Label("Scheda", systemImage:"list.bullet.clipboard") }
            NavigationStack { AnalyticsView(store: store) }.tabItem { Label("Progressi", systemImage:"chart.line.uptrend.xyaxis") }
            NavigationStack { AddExerciseView(store: store) }.tabItem { Label("Aggiungi", systemImage:"plus.circle") }
            NavigationStack { SettingsView(store: store) }.tabItem { Label("Impostazioni", systemImage:"gearshape") }
        }
        .sheet(isPresented:$showingImporter) { SheetImportView(store:store) }
        .tint(.purple)
    }
}

struct DashboardView: View {
    @ObservedObject var store: WorkoutStore
    @Binding var showImporter: Bool
    var body: some View {
        ScrollView {
            VStack(spacing:16) {
                HStack { Text("GYM TRACKER PRO").font(.system(size:26,weight:.black)); Spacer(); Button { showImporter=true } label:{ Image(systemName:"camera.fill").font(.title3).padding(10).background(.purple.opacity(0.15),in:.circle) } }
                Picker("Giorno",selection:$store.selectedDay) { ForEach(store.days,id:\.self){Text($0)} }.pickerStyle(.menu).frame(maxWidth:.infinity,alignment:.leading)
                HStack(spacing:12) { Metric(title:"Esercizi",value:"\(store.dayExercises.count)",icon:"figure.strengthtraining.traditional"); Metric(title:"Serie",value:"\(store.totalSets)",icon:"square.stack.3d.up"); Metric(title:"Completate",value:"\(store.completedSets)",icon:"checkmark.circle") }
                SwiftUI.ProgressView(value: store.totalSets == 0 ? 0 : Double(store.completedSets)/Double(store.totalSets)).tint(.purple)
                if store.dayExercises.isEmpty { EmptyDayView() } else { ForEach(store.dayExercises) { exercise in ExerciseCard(store:store,exercise:exercise) } }
            }.padding()
        }.navigationTitle(store.selectedDay).toolbar { ToolbarItem(placement:.topBarTrailing){Button("Reset"){store.resetDay()}} }
    }
}
struct Metric: View { let title:String; let value:String; let icon:String; var body:some View{VStack(alignment:.leading,spacing:5){Image(systemName:icon);Text(value).font(.title2.bold());Text(title).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding().background(.thinMaterial,in:RoundedRectangle(cornerRadius:18))} }
struct EmptyDayView: View { var body:some View{ContentUnavailableView("Giorno libero", systemImage: "calendar.badge.plus", description: Text("Aggiungi gli esercizi che vuoi per questo giorno."))} }

struct ExerciseCard: View {
    @ObservedObject var store: WorkoutStore
    let exercise: Exercise
    @State private var editing = false
    @State private var weightText:[UUID:String] = [:]
    @State private var repsText:[UUID:String] = [:]
    @FocusState private var focused: UUID?
    @State private var timerStart: Date?
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(alignment:.top) { VStack(alignment:.leading,spacing:3){Text(exercise.name).font(.headline);Text(exercise.group).font(.caption.bold()).foregroundStyle(.purple);Text(exercise.focus).font(.caption).foregroundStyle(.secondary)}; Spacer(); Button(editing ? "Fine":"Modifica"){editing.toggle()} }
            HStack { Text("Recupero").font(.caption.bold()); TextField("2:00",text:Binding(get:{exercise.recovery},set:{store.setRecovery($0,exerciseID:exercise.id)})).textFieldStyle(.roundedBorder).frame(width:90).disabled(!editing); Spacer(); Text(exercise.target.title).font(.caption2).padding(7).background(.purple.opacity(0.12),in:Capsule()) }
            ForEach(Array(exercise.sets.enumerated()),id:\.element.id) { index,set in
                SetRow(store:store,exercise:exercise,index:index,set:set,editing:editing,weightText:$weightText,repsText:$repsText,focused:$focused)
            }
            HStack { Button("+ Serie"){store.addSet(to:exercise.id)}.buttonStyle(.bordered); Button("− Serie"){store.removeSet(from:exercise.id)}.buttonStyle(.bordered); Spacer(); Text("\(exercise.sets.count) serie").font(.caption).foregroundStyle(.secondary) }
            MuscleMapView(target: exercise.target).frame(height:150).clipShape(RoundedRectangle(cornerRadius:18))
        }.padding().background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:24)).overlay(RoundedRectangle(cornerRadius:24).stroke(.purple.opacity(0.15)))
    }
}

struct SetRow: View {
    @ObservedObject var store: WorkoutStore; let exercise:Exercise; let index:Int; let set:WorkoutSet; let editing:Bool
    @Binding var weightText:[UUID:String]; @Binding var repsText:[UUID:String]; var focused:FocusState<UUID?>.Binding
    var body: some View {
        HStack(spacing:10) {
            Text("S\(index+1)").font(.caption.bold()).frame(width:30)
            TextField(set.reps,text:Binding(get:{repsText[set.id] ?? set.reps},set:{repsText[set.id]=$0;store.setReps($0,exerciseID:exercise.id,setID:set.id)})).textFieldStyle(.roundedBorder).frame(width:75).disabled(!editing)
            TextField("kg",text:Binding(get:{weightText[set.id] ?? (set.weight == 0 ? "" : String(format:"%.1f",set.weight).replacingOccurrences(of:".0",with:""))},set:{weightText[set.id]=$0})).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).frame(width:75).focused(focused, equals: set.id).disabled(!editing).onSubmit{commitWeight()}.onChange(of:focused.wrappedValue){ if $0 == nil { commitWeight() } }
            Button { store.toggle(exercise.id,setID:set.id) } label: { Image(systemName:set.completed ? "checkmark.circle.fill":"circle").font(.title3) }.buttonStyle(.plain)
            if set.completed { Text("✓").font(.caption).foregroundStyle(.green) }
            Spacer()
        }.toolbar { ToolbarItemGroup(placement:.keyboard){Spacer();Button("Fine"){focused.wrappedValue=nil}} }
    }
    func commitWeight(){ let raw=weightText[set.id] ?? ""; let normalized=raw.replacingOccurrences(of:",",with:"."); guard let value=Double(normalized) else { if raw.isEmpty { store.updateWeight(0,exerciseID:exercise.id,setID:set.id,saveHistory:false) }; return }; store.updateWeight(value,exerciseID:exercise.id,setID:set.id); weightText[set.id]=String(format:"%.1f",value).replacingOccurrences(of:".0",with:"") }
}

struct AnalyticsView: View {
    @ObservedObject var store: WorkoutStore
    @State private var selected: Exercise?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Progressi").font(.largeTitle.bold())
                Text("Lo storico registra data e peso di ogni aggiornamento.").font(.subheadline).foregroundStyle(.secondary)
                ForEach(store.exercises) { exercise in
                    Button { selected = exercise } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text(exercise.name).font(.headline); Spacer(); Text("Max \(format(store.maxWeight(for: exercise))) kg").font(.caption.bold()) }
                            ExerciseChart(history: store.history(for: exercise))
                        }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain)
                }
            }.padding()
        }.navigationTitle("Progressi").sheet(item: $selected) { exercise in
            NavigationStack { ExerciseHistoryView(store: store, exercise: exercise) }
        }
    }
    func format(_ v: Double) -> String { String(format: "%.1f", v).replacingOccurrences(of: ".0", with: "") }
}

struct ExerciseChart: View {
    let history: [WeightLog]
    var body: some View {
        if history.count > 0 {
            Chart(history) { item in
                LineMark(x: .value("Data", item.date), y: .value("Kg", item.weight)).interpolationMethod(.catmullRom)
                PointMark(x: .value("Data", item.date), y: .value("Kg", item.weight))
            }.frame(height: 150)
        } else {
            Text("Nessuno storico ancora: inserisci e conferma un nuovo peso.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct ExerciseHistoryView:View{ @ObservedObject var store:WorkoutStore; let exercise:Exercise; var body:some View{List{ForEach(store.history(for:exercise)){l in HStack{Text(l.date.formatted(date:.abbreviated,time:.shortened));Spacer();Text("\(String(format:"%.1f",l.weight)) kg").bold()}}}.navigationTitle(exercise.name)} }

struct AddExerciseView: View {
    @ObservedObject var store:WorkoutStore; @State private var name=""; @State private var reps="8-10"; @State private var sets=3; @State private var recovery="2:00"; @State private var weights:[String]=["20","20","20"]; @FocusState private var field:Bool
    var body:some View{Form{Section("Giorno"){Picker("Giorno",selection:$store.selectedDay){ForEach(store.days,id:\.self){Text($0)}}};Section("Esercizio"){TextField("Nome",text:$name).focused($field);TextField("Ripetizioni",text:$reps);Stepper("Serie: \(sets)",value:$sets,in:1...20).onChange(of:sets){newValue in if weights.count<newValue{weights += Array(repeating:"20",count:newValue-weights.count)}else{weights=Array(weights.prefix(newValue))}};TextField("Recupero (es. 2:00)",text:$recovery)};Section("Kg per serie"){ForEach(0..<weights.count,id:\.self){i in TextField("Serie \(i+1)",text:$weights[i]).keyboardType(.decimalPad)} };Button("Aggiungi alla scheda"){let ws=weights.map{Double($0.replacingOccurrences(of:",",with:".")) ?? 0};store.addExercise(day:store.selectedDay,name:name,reps:reps,weights:ws,recovery:recovery);name=""}}.toolbar{ToolbarItemGroup(placement:.keyboard){Spacer();Button("Fine"){field=false}}}.navigationTitle("Aggiungi esercizio")}
}

struct SheetImportView: View {
    @ObservedObject var store:WorkoutStore; @StateObject private var importer=SheetImporter(); @Environment(\.dismiss) private var dismiss; @State private var camera=false; @State private var photoItem: PhotosPickerItem?; @State private var showingDoc=false
    var body:some View{NavigationStack{ScrollView{VStack(spacing:16){HStack{Button("📷 Foto"){camera=true}.buttonStyle(.borderedProminent);Button("📄 PDF"){showingDoc=true}.buttonStyle(.bordered);};Text("Oppure scegli una foto dalla galleria").font(.caption).foregroundStyle(.secondary);PhotosPicker(selection:$photoItem,matching:.images){Label("Scegli foto",systemImage:"photo")}.buttonStyle(.bordered).onChange(of:photoItem){ item in if let item { Task { if let d=try? await item.loadTransferable(type:Data.self), let img=UIImage(data:d){ importer.analyze(image:img) } } } }
            if importer.isBusy{ProgressView("Analizzo la scheda…")}; if !importer.items.isEmpty{Text("Controlla prima di importare").font(.headline);ForEach(importer.items){item in VStack(alignment:.leading){Text(item.name).bold();Text("\(item.day) · \(item.sets) serie · \(item.reps) · recupero \(item.recovery.isEmpty ? "—":item.recovery)").font(.caption).foregroundStyle(.secondary);Button("Importa"){store.addImported(item)}.buttonStyle(.borderedProminent)}.frame(maxWidth:.infinity,alignment:.leading).padding().background(.thinMaterial,in:RoundedRectangle(cornerRadius:16))}}; if !importer.recognizedText.isEmpty{DisclosureGroup("Testo riconosciuto"){Text(importer.recognizedText).font(.caption).textSelection(.enabled)}}}.padding()}.navigationTitle("Importa scheda").toolbar{ToolbarItem(placement:.topBarTrailing){Button("Chiudi"){dismiss()}}}.sheet(isPresented:$camera){CameraPicker{image in importer.analyze(image:image)}}.fileImporter(isPresented:$showingDoc,allowedContentTypes:[.pdf],allowsMultipleSelection:false){res in if case .success(let urls)=res,let u=urls.first{importer.analyze(pdfURL:u)}}}}
}

struct SettingsView:View{@ObservedObject var store:WorkoutStore;var body:some View{Form{Section("Dati"){Text("I dati vengono salvati localmente sul telefono.");Button("Richiedi notifiche"){RecoveryNotifications.shared.requestPermission()}};Section("Settimana"){ForEach(store.days,id:\.self){d in HStack{Text(d);Spacer();Text("\(store.exercises.filter{$0.day==d}.count) esercizi").foregroundStyle(.secondary)}}}}.navigationTitle("Impostazioni")}}

#Preview { ContentView() }
