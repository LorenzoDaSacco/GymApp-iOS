let seconds = max(0, Int(self))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
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

            Section("Giorno attuale") {
                Text(store.currentCalendarDate.formatted(
                    Date.FormatStyle()
                        .weekday(.wide)
                        .day()
                        .month(.wide)
                        .year()
                ))
                .font(.subheadline.bold())
                .foregroundStyle(accentColor)

                Text("Il giorno viene letto automaticamente dal calendario dell'iPhone e cambia alle 00:00. In modalità GIORNO 1, 2, 3... viene usata l'associazione che hai impostato sopra.")
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

            Section("Promemoria progressione") {
                Label("La progressione si gestisce in ogni esercizio", systemImage: "arrow.up.forward")
                Text("Apri Scheda → Modifica sull'esercizio → Ricordami di progredire. L'app ti avvisa quando hai raggiunto le ripetizioni previste, ma il nuovo carico lo scegli tu.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Widget e diagnostica") {
                Label(store.widgetDiagnostics, systemImage: store.widgetSharingAvailable ? "checkmark.shield" : "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(store.widgetSharingAvailable ? .green : .orange)
                Button { store.refreshWidgets() } label: {
                    Label("Sincronizza i widget", systemImage: "arrow.triangle.2.circlepath")
                }
                Text("Se il contenitore condiviso non è disponibile, la causa è probabilmente la firma dell'IPA/App Group: SideStore non può correggerla dalla sola app. Non eliminare l'app per tentare la riparazione.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Allenamento monitorato") {
                NavigationLink("Avvia allenamento e calcolo calorie") {
                    MonitoredWorkoutView(store: store)
                }
                Text("Registra i BPM ricevuti dal Nilox, il grafico e le calorie attive stimate per la sessione.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Nilox ONAIR") {
                Label("Monitoraggio cardiaco", systemImage: "heart.text.square")
                Text("Apri la scheda Cuore per collegare il bracciale e visualizzare le letture ogni 10 minuti. Lo storico del cuore è separato da quello degli esercizi.")
                    .font(.caption).foregroundStyle(.secondary)
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
    ContentView().environmentObject(WorkoutStore()).environmentObject(HeartRateMonitor())
}