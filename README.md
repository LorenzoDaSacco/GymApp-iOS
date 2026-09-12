# Gym Tracker Pro – GitHub build

Fix inclusi in questa versione:
- timer di recupero / Live Activity indipendente dal giorno della settimana (LUNEDÌ–DOMENICA);
- notifica locale al termine del recupero;
- timer e barra visibili nell'app e Live Activity su Lock Screen/Dynamic Island;
- aggiunta serie senza ricostruire o cancellare le serie già esistenti;
- i pesi delle serie esistenti vengono mantenuti quando si aggiunge o rimuove una serie;
- il campo peso non salva più uno 0 quando viene cancellato temporaneamente;
- salvataggio dei pesi solo quando necessario, evitando il salvataggio a ogni carattere;
- rimosso il reload continuo dei widget a ogni modifica, causa di rallentamenti;
- icona AppIcon presente nel catalogo asset;
- RecoveryActivityAttributes.swift presente una sola volta e collegato ai target corretti.
