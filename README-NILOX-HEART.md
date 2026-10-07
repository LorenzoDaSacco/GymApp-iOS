# GymApp iOS 1.2 – Nilox ONAIR / Cuore

## Funzionalità aggiunte

- Nuova scheda **Cuore** nella barra inferiore.
- Connessione **volontaria** al Nilox ONAIR usando Core Bluetooth e servizi BLE standard `180D` / `2A37` già verificati sul dispositivo.
- Quando arrivano notifiche cardiache BLE, l'app salva **una fascia di 10 minuti** con media, minimo, massimo e numero di notifiche ricevute. Una fascia senza letture **rimane vuota**.
- Recap giornaliero con orari, grafico e media/minimo/massimo; andamento degli ultimi 7 giorni.
- Memorizzazione indipendente dallo storico allenamenti in `Application Support/NiloxHeartHistory-v1.json`.
- Supporto `bluetooth-central` in background e **state preservation/restoration** di Core Bluetooth: iOS può risvegliare l'app per eventi BLE, ma NON è assicurata la raccolta esatta ogni 10 minuti o 24 ore su 24.
- Attivazione/disattivazione e riconnessione dalla scheda Cuore.

## Configurazione iPhone

1. Compila il progetto con l'azione GitHub **Build GymApp iOS** (l'IPA generato è NON firmato).
2. Firma l'IPA tramite il tuo metodo di installazione. **Aggiorna sopra l'app esistente, senza cancellarla.** Bundle ID e impostazioni salvataggio allenamenti sono invariati. Il mantenimento dei dati dipende comunque da una firma compatibile: fare un backup prima di cambiare firma.
3. Apri GymApp → **Cuore** → **Avvia monitoraggio**.
4. Consenti l'accesso Bluetooth e tieni ONAIR vicino; per il primo collegamento evita che Heart Graph o l'app Nilox mantengano una connessione BLE al dispositivo.
5. I dati appariranno negli intervalli effettivamente ricevuti. Lo schermo bloccato non dovrebbe interrompere necessariamente i servizi BLE, ma iOS può sospendere la raccolta; **non chiudere forzatamente GymApp dal selettore delle app**.
6. Per interrompere l'uso BLE e ridurre il consumo della batteria: scheda Cuore → **Interrompi monitoraggio**.

## Limiti e privacy

- **Non comanda al Nilox di eseguire una misurazione ogni 10 minuti**: ascolta le notifiche spontanee del sensore e raggruppa quelle disponibili.
- Mancanza di dati non equivale a 0 BPM. Media/minimo/massimo si riferiscono solo agli intervalli effettivamente registrati.
- **Non integra ancora Apple Salute / HealthKit**, perché occorrono capability ed entitlement di firma aggiuntivi; è possibile studiare un'implementazione successiva con firma compatibile.
- Il nuovo storico è locale, non condiviso con server e non cambia/modifica il database o il formato degli allenamenti.
- La connessione può non riattivarsi dopo chiusura forzata, perdita prolungata della connessione, revoca dei permessi, riavvio e altri limiti imposti da iOS.
- Per le estensioni widget già presenti resta la necessità di una firma corretta delle extension.
- Non usare per diagnosi mediche, alert di emergenza o valutazioni cliniche.

## Verifiche effettuate

- Parsing sintattico Swift su tutti i sorgenti (Linux Swift 6.2).
- Test nativi Foundation sull'aggregazione in fasce, giorni, intervalli mancanti, limiti BPM e codifica/decodifica JSON.
- Validazione Info.plist e struttura pbxproj.
- **Non compilata con Xcode** e non testata su iPhone: è necessario il build GitHub Actions e il test sul dispositivo.


## Revisione 1.2.1: ONAIR presente nel Bluetooth iPhone, ma non rilevato

- Recupera i dispositivi cardiaci già collegati al sistema con `retrieveConnectedPeripherals(withServices: [180D])`: questi potrebbero non trasmettere annunci BLE durante una connessione.
- Riconosce anche nomi che contengono `ONAIR`, ignorando maiuscole/minuscole e suffissi.
- Elenca i dispositivi BLE rilevati e consente la scelta manuale dall'interfaccia Cuore. La scelta serve a verificare il servizio standard; il monitor non invia comandi proprietari.
- Memorizza un identificativo iOS soltanto dopo aver verificato che il dispositivo espone `180D`.
- Restano invariati Bundle ID, database allenamenti, formato storico cardiaco e dati degli esercizi.
- Se il dispositivo è occupato da altre app: sospendere temporaneamente il permesso Bluetooth alle app Nilox e Heart Graph, lasciare attivo quello a GymApp, quindi usare «Cerca di nuovo il bracciale».
- La lista mostra ID CoreBluetooth di iOS, non indirizzi MAC: non cercare per `FE:51:13:37:C5:FB` nel telefono.

**Limite:** la compilazione iOS e il comportamento del collegamento sul dispositivo devono essere verificati tramite Xcode/GitHub Actions. Il metodo non garantisce campionamento 24/7 in background.
