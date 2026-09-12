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
