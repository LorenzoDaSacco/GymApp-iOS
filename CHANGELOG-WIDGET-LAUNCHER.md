# Widget rapido Gym Tracker Pro

- Aggiunto widget statico nelle dimensioni piccolo e medio; al tocco apre l’app.
- Il widget non legge il database e non dipende dall’App Group.
- Rimossi dal catalogo i quattro widget con contatori non aggiornati; la relativa implementazione rimane nel sorgente per futuri interventi.
- Nessuna modifica a dati, Bundle ID, esercizi o impostazioni dell’app.
- Il progetto va compilato con GitHub Actions e firmato per iPhone; non è un IPA già pronto.
- Nessuna integrazione Nilox aggiunta: per leggere i dati da Apple Salute servono HealthKit e capability/permessi compatibili con la firma.
