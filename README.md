# GymApp iOS

Versione aggiornata del progetto con:

- timer di recupero per **qualsiasi giorno della settimana** (lunedì-domenica);
- notifica locale alla fine di ogni recupero;
- Live Activity su schermata di blocco / Dynamic Island;
- fallback automatico a 2:00 se un esercizio non ha un tempo di recupero impostato;
- peso delle serie preservato quando si aggiunge una nuova serie;
- commit del peso digitato prima di `+ Serie`;
- niente reload del widget a ogni modifica;
- mappa muscolare caricata una sola volta per esercizio/target, evitando il lag causato dal reload continuo della WKWebView;
- campi ripetizioni e recupero modificati localmente e salvati quando l'editing termina.

Per le Live Activities, su iPhone devono essere abilitate nelle impostazioni di sistema e l'app deve avere i permessi per le notifiche.


## Novità: widget e progressione del carico
- Impostazioni → Widget → Aggiorna i widget ora: rigenera lo snapshot e richiede a WidgetKit un aggiornamento.
- Widget disponibili: scheda di oggi, esercizi e serie combinati, esercizi completati, serie completate.
- Impostazioni → Progressione dei carichi: attiva un promemoria locale opzionale e scegli l'incremento di peso.
- La notifica arriva quando tutte le serie normali dell'esercizio sono complete e tutte raggiungono almeno le ripetizioni target; non cambia i carichi memorizzati. Non valuta RPE/RIR, quindi è un suggerimento da confermare, non una prescrizione automatica.

### Essenziale per i widget su iPhone
L'IPA generato da GitHub Actions è **non firmato**. L'app e l'estensione `GymWidgets.appex` devono essere firmate con certificati/provisioning compatibili e App Groups abilitato per **entrambi** con `group.com.gymtrackerpro.shared`. Se il metodo di sideload non conserva gli entitlement, i widget possono non comparire o mostrare dati vuoti. Non è possibile correggere questo requisito con un semplice reload del codice.

## Novità: Nilox ONAIR – monitoraggio cardiaco

Vedi [README-NILOX-HEART.md](README-NILOX-HEART.md) per istruzioni, limitazioni sul background iOS e gestione dei dati. La nuova funzione è nella scheda **Cuore**; lo storico viene salvato separatamente dagli allenamenti.
