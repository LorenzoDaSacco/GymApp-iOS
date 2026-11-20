# CHANGELOG — GymApp-iOS

## 1.3.2 (build 16) — 2026-11-20
Correzioni nella schermata Scheda (HUD e resto invariati):
1. Scroll: il gesto SwiftUI LongPress+Drag, che interferiva con lo scorrimento verticale, è sostituito da un long-press nativo UIKit sullo UIScrollView. Lo scroll di sistema ha priorità; il drag parte solo dopo 0,35 s di pressione ferma su una card. Rimossa la PreferenceKey delle altezze (ora lette dalle viste-àncora delle card).
2. Indicatore di destinazione: durante il drag, nello slot esatto in cui verrà rilasciata la card compare un riquadro corallo tratteggiato con riempimento leggero, che si aggiorna in tempo reale; la card trascinata ha anche una leggera ombra.
Versione 1.3.1 (15) → 1.3.2 (16). Non verificato: compilazione Xcode e prova su dispositivo.

## 1.3.1 (build 15) — 2026-11-20
Correzioni su richiesta (HUD e grafica invariati, tranne i 2 fix):
1. Drag-and-drop: sostituito `onDrag/onDrop` (che spostava solo un'anteprima di sistema) con un gesto tieni-premuto+trascina che muove la card reale su e giù, con riordino in tempo reale, scroll automatico vicino al bordo alto/basso e vibrazione al "sollevamento". Ordine salvato a ogni scambio.
2. Progressione: rimosso dalla Scheda il vecchio controllo (menu/icona) e l'interruttore in Modifica; aggiunto un pulsante dedicato a tutta larghezza sotto l'intestazione della card (acceso/spento ben distinguibili). Il menu ⋯ della schermata «Inizia allenamento» è invariato. Testo in Impostazioni aggiornato.
Altro: versione 1.3.0 (14) → 1.3.1 (15). Non verificato: compilazione Xcode e prova su dispositivo.

## 1.3.0 (build 14) — 2026-11-18
Richieste utente (8 modifiche, HUD e grafica invariati):
1. Drag-and-drop: pressione prolungata su un esercizio per riordinarlo nella giornata (salvato).
2. "Inizia allenamento": il peso modificato aggiorna subito la scheda base, anche uscendo senza "Completa serie"; lo storico registra una sola modifica.
3. Smartband: accettate caratteristiche notify/indicate, diagnosi dedicate (servizio non standard, associazione richiesta), elenco dispositivi esteso (anche già collegati a iOS), ordinamento che porta i bracciali in cima, collegamento automatico se iOS ha un solo sensore cardiaco collegato, messaggi col nome del bracciale. Nessun comando proprietario inviato.
4. "Aggiungi" spostato dalla barra in basso alla barra in alto della Scheda (stessa icona e testo).
5. Progressive Overload: icona freccia ↑ nella Scheda (piena se attivo) + interruttore "Ricordami di progredire" in Modifica; testo aggiornato in Impostazioni.
6. "Allenamento monitorato" → "Inizia allenamento"; senza bracciale non parte la ricerca Bluetooth e compare un messaggio informativo.
7. Rimossi i "Fine" della tastiera duplicati su ogni riga serie; la modifica salva il peso in digitazione alla chiusura; scorrendo la tastiera si chiude.
8. Widget: rimasto solo "Apri Gym Tracker Pro" (tasto rapido); rimossi i 4 widget con contatori; estensione senza App Group; versioni app/estensione allineate; niente reload widget a ogni salvataggio.
Altro: versione 1.2.1 (13) → 1.3.0 (14).
Non verificato: compilazione Xcode e prova su dispositivo.
