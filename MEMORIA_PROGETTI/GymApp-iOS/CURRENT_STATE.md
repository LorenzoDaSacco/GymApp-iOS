# CURRENT_STATE — GymApp-iOS (Gym Tracker Pro)

Aggiornato: 2026-11-20 · Versione: 1.3.1 (build 15)

## Progetto
App iOS SwiftUI (iOS 17+) di gestione scheda palestra, con timer di recupero (notifiche + Live Activity),
progressi per esercizio, scheda Cuore (Nilox ONAIR e altri bracciali BLE) e un widget.
Target: `GymApp` (app) e `GymWidgets` (estensione: 1 widget + Live Activity). Build tramite GitHub Actions (IPA non firmato).

## Regola suprema (dall'utente)
NON toccare in nessun modo HUD, layout visivo e grafica esistenti. Invarianza totale: ogni modifica deve essere
logica/funzionale, salvo le variazioni di interfaccia esplicitamente richieste.

## Stato delle 8 richieste del 2026-11-18
| # | Richiesta | Stato | Dove |
|---|-----------|-------|------|
| 1 | Drag-and-drop esercizi (pressione prolungata) | Rifatto in 1.3.1: si trascina la card reale (non l'anteprima di sistema), riordino live, scroll automatico ai bordi. Non testato su device | `ContentView.swift` (`ExerciseDragController`, `ReorderableExerciseCard`, `ScrollViewFinder`), `WorkoutStore.reorderExercise` |
| 2 | Sync peso live in "Inizia allenamento" | Implementato, non testato su device | `ContentView.swift` (MonitoredWorkoutView: `weightTarget`, `liveSyncWeight`, `commitWeightEdit`), `WorkoutStore.updateWeight(previous:)` |
| 3 | Smartband universali | Implementato (standard BLE 180D/2A37), non testato con hardware | `HeartRateMonitor.swift` |
| 4 | "Aggiungi" in alto nella scheda | Implementato (tab rimossa, pulsante in alto a sinistra della Scheda) | `ContentView.swift` |
| 5 | UX Progressive Overload | Rifatto in 1.3.1: vecchio controllo (menu/icona) rimosso dalla Scheda e sostituito da un pulsante dedicato a tutta larghezza sotto l'intestazione della card. Non testato su device | `ContentView.swift` (`ProgressionReminderButton`) |
| 6 | Rinomina in "Inizia allenamento" | Implementato (testi) + funziona senza bracciale | `ContentView.swift`, `HeartRateMonitor.beginWorkoutRecording` |
| 7 | Tastiera pesi: via i "Fine" inutili | Implementato (rimossi quelli per riga) | `ContentView.swift` (SetRow) |
| 8 | Widget: esattamente 1, tasto rapido | Implementato | `GymWidgets/GymWidgets.swift`, `GymWidgets.entitlements`, plist |

## Decisioni di interpretazione (da confermare con l'utente se non corrispondono)
- #4 "Aggiungi": la tab in basso è stata rimossa e il pulsante (stessa icona `plus.circle` + testo) è nella barra in alto a sinistra della Scheda; apre la schermata esistente "Aggiungi esercizio" in push.
- #5: pulsante «Ricordami di progredire» (contorno chiaro = spento, pieno con testo «Promemoria progressione attivo» = acceso) sotto il titolo di ogni card. La schermata «Inizia allenamento» (HUD) conserva il menu ⋯ originale: non è stata toccata per l'invarianza; se va sostituito anche lì, chiedere conferma.
- #1 (dettagli tecnici): gesto LongPress(0,35 s)+Drag; la card segue il dito con `offset`, scambio quando il centro supera quello della vicina; lo ScrollView viene disabilitato durante il trascino e lo scroll è guidato da un CADisplayLink (zona di 90 pt dai bordi, fino a 900 pt/s) sullo UIScrollView trovato risalendo la gerarchia. Se lo UIScrollView non fosse trovato il trascino funziona senza scroll automatico. Nessun feedback grafico oltre a leggero ingrandimento (1,02) e vibrazione durante il trascino.
- #7: «tieni solo quello della scheda in modalità modifica» interpretato come: restano solo il tasto "Fine" della scheda (intestazione) e quelli delle schermate con un solo campo (Aggiungi, Inizia allenamento). Aggiunto `scrollDismissesKeyboard(.interactively)` per chiudere la tastiera scorrendo.
- #8: il widget rimasto è `GymLauncherWidget` (grafica invariata, famiglie small + medium). I 4 widget con contatori sono stati rimossi dal sorgente (recuperabili da Git). Il widget non richiede più l'App Group.

## Verifiche eseguite / non eseguite
- Eseguito: controllo statico delle parentesi su tutti i file Swift; revisione del diff; coerenza dei riferimenti.
- NON eseguito: compilazione con Xcode e prova su iPhone (nessun toolchain Swift/macOS in questo ambiente). Serve il build GitHub Actions + test manuale (vedi TODO).

## File di memoria non trovati
`MEMORIA_PROGETTI`, `REGOLE_OBIETTIVI.md`, `OBBIETTIVI.md` (85 obiettivi) e `VERIFICHE.json` non esistevano né nello ZIP né nell'ambiente: questa cartella è stata creata ex novo. Se esistono altrove, vanno allegati.
