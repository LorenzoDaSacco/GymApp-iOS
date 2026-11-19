# TODO — GymApp-iOS

## Da fare subito (verifica su build reale)
- [ ] Lanciare il workflow GitHub "Build GymApp iOS" e correggere eventuali errori di compilazione (il codice non è stato compilato qui).
- [ ] Test su iPhone — drag-and-drop: tieni premuto su un esercizio e portalo dall'ultima alla prima posizione; riavvia l'app e verifica che l'ordine resti.
- [ ] Test su iPhone — sync peso: "Inizia allenamento" → modifica il peso → Chiudi/indietro senza "Completa serie" → il peso nella Scheda è aggiornato; controlla che lo storico (Progressi) abbia un solo punto per la modifica.
- [ ] Test — "Aggiungi" in alto nella Scheda: aggiungi un esercizio e verifica ritorno alla Scheda sul giorno scelto.
- [ ] Test — tastiera pesi in Modifica: nessun "Fine" sulla tastiera; "Fine" nell'intestazione salva il peso.
- [ ] Test — widget: nella galleria compare un solo widget "Apri Gym Tracker Pro" e il tocco apre l'app.
- [ ] Test con il proprio bracciale (ONAIR e almeno un altro): selezione dall'elenco in scheda Cuore.

## Possibili miglioramenti (non richiesti, da valutare)
- [ ] Se il widget va ingrandito: valutare la famiglia `.systemLarge` (richiede decisione sulla grafica).
- [ ] Se l'utente vuole il "Fine" anche sulla tastiera: aggiungerne uno solo a livello di Scheda.
