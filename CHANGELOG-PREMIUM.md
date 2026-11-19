# GymApp — revisione UX e progressione per esercizio

## Modifiche
- Progressione configurabile in **Scheda → Modifica** per ogni singolo esercizio.
- Non viene suggerito un numero fisso di kg. Dopo aver raggiunto le ripetizioni obiettivo in tutte le serie normali, compare un avviso persistente nella scheda e viene inviata una notifica, se autorizzata.
- L’avviso si chiude manualmente con la spunta; **non modifica i carichi**.
- Dashboard ridisegnata (titolo, selezione giorno, riepilogo sessione); pannello progressione integrato nella scheda; miglioramenti estetici widget.
- Schermata di diagnostica App Group in Impostazioni per identificare alcuni errori di accesso ai dati dei widget.

## Compatibilità e limiti
- Non cambia il formato dei dati degli allenamenti, né `GymShared.workoutsKey` o i Bundle ID del progetto. Le preferenze della progressione usano chiavi `UserDefaults` per esercizio.
- La vecchia impostazione globale di progressione non viene più utilizzata: riattivare l'opzione sugli esercizi desiderati.
- **Non è una IPA**: è un progetto Xcode da compilare e firmare. La compilazione iOS e il funzionamento widget su dispositivo **non sono stati verificati** in questo ambiente.
- SideStore con account Apple gratuito potrebbe non poter autorizzare il gruppo di condivisione richiesto ai widget. Una diagnostica positiva non dimostra che i permessi siano effettivamente concessi al widget.
- Non cancellare l'app installata per aggiornare. Prima effettuare un backup indipendente verificato dei dati.
