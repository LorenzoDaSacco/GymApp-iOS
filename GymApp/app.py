import sqlite3
import streamlit as st

# --- CONFIGURAZIONE DATABASE ---
DB_NAME = "palestra_v14.db"

def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS serie_esercizio (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            giorno TEXT NOT NULL,
            nome_esercizio TEXT NOT NULL,
            gruppo_muscolare TEXT NOT NULL,
            numero_serie INTEGER NOT NULL,
            ripetizioni TEXT NOT NULL,
            peso REAL NOT NULL,
            completato BOOLEAN NOT NULL DEFAULT 0
        )
    """)
    conn.commit()
    conn.close()

init_db()

# --- MOTORE INTELLIGENTE UNIVERSALE PER I MUSCOLI ---
import unicodedata
import re

def _normalizza_testo(testo):
    """Minuscole, accenti rimossi e spazi uniformati per riconoscere varianti."""
    testo = str(testo).strip().lower()
    testo = unicodedata.normalize("NFD", testo)
    testo = "".join(c for c in testo if unicodedata.category(c) != "Mn")
    testo = re.sub(r"[^a-z0-9]+", " ", testo)
    return re.sub(r"\s+", " ", testo).strip()

# Regole ordinate: le più specifiche vengono controllate prima.
# Ogni esercizio restituisce:
# nome visualizzato, gruppo, descrizione, target SVG.

# --- ESERCIZI DELLA SCHEDA PERSONALE (PDF) ---
# Queste regole vengono prima del catalogo generico, così le varianti usate
# nella scheda dell'utente vengono riconosciute in modo deterministico.
ESERCIZI_SCHEDA = [
    ([
        "spinte manubri panca 32", "spinte manubri panca 32 gradi",
        "spinte manubri panca 32°", "panca 32 manubri",
        "spinte manubri panca inclinata 32"
    ], "PETTO (ALTO)", "Focus: Pettorali superiori e tricipiti · Scheda personale", "chest"),

    ([
        "lat pulldown"
    ], "DORSO", "Focus: Gran dorsale e bicipiti · Scheda personale", "back"),

    ([
        "chest press"
    ], "PETTO", "Focus: Pettorali e tricipiti · Scheda personale", "chest"),

    ([
        "t bar prona larga", "t-bar prona larga",
        "t bar presa prona larga", "t-bar presa prona larga",
        "t bar row wide pronated", "t bar row wide grip",
        "tbar prona larga", "tbar wide grip"
    ], "DORSO", "Focus: Dorsali, romboidi e trapezio · Scheda personale", "back"),

    ([
        "alzate laterali"
    ], "SPALLE", "Focus: Deltoide laterale · Scheda personale", "shoulders"),

    ([
        "push down asta curva", "pushdown asta curva",
        "push down barra curva", "pushdown barra curva"
    ], "TRICIPITI", "Focus: Tricipiti · Scheda personale", "triceps"),

    ([
        "curl cavo basso", "curl al cavo basso", "curl cavo"
    ], "BICIPITI", "Focus: Bicipiti · Scheda personale", "biceps"),

    ([
        "leg extension"
    ], "QUADRICIPITI", "Focus: Quadricipiti · Scheda personale", "quads"),

    ([
        "leg press 45", "leg press a 45", "pressa 45"
    ], "GAMBE (QUADRICIPITI)", "Focus: Quadricipiti e glutei · Scheda personale", "quads"),

    ([
        "leg curl sdraiato"
    ], "FEMORALI", "Focus: Femorali · Scheda personale", "hamstrings"),

    ([
        "adduttori"
    ], "ADDUTTORI", "Focus: Adduttori · Scheda personale", "hamstrings"),

    ([
        "calf machine"
    ], "POLPACCI", "Focus: Polpacci · Scheda personale", "quads"),

    ([
        "panca piana bilanciere"
    ], "PETTO", "Focus: Pettorali e tricipiti · Scheda personale", "chest"),

    ([
        "rematore bilanciere"
    ], "DORSO", "Focus: Dorsali, romboidi e bicipiti · Scheda personale", "back"),

    ([
        "lento avanti manubri panca 71", "lento avanti manubri",
        "lento avanti panca 71"
    ], "SPALLE", "Focus: Deltoidi e tricipiti · Scheda personale", "shoulders"),

    ([
        "rowing"
    ], "DORSO", "Focus: Dorsali e romboidi · Scheda personale", "back"),

    ([
        "stacchi rumeni manubri", "stacco rumeno manubri"
    ], "FEMORALI / GLUTEI", "Focus: Catena posteriore e glutei · Scheda personale", "hamstrings"),

    ([
        "leg curl seduto"
    ], "FEMORALI", "Focus: Femorali · Scheda personale", "hamstrings"),

    ([
        "arm curl"
    ], "BICIPITI", "Focus: Bicipiti · Scheda personale", "biceps"),

    ([
        "french press manubri"
    ], "TRICIPITI", "Focus: Tricipiti · Scheda personale", "triceps"),
]

CATALOGO_COMPLETO = [(['panca piana', 'bench press', 'barbell bench press', 'flat bench press', 'distensioni bilanciere panca piana'], 'PETTO', 'Focus: Pettorali e tricipiti', 'chest'), (['panca inclinata', 'incline bench press', 'incline barbell press', 'panca 30', 'panca 32', 'panca 35', 'panca 45'], 'PETTO (ALTO)', 'Focus: Pettorali superiori e tricipiti', 'chest'), (['panca declinata', 'decline bench press', 'decline press'], 'PETTO', 'Focus: Pettorali inferiori e tricipiti', 'chest'), (['panca piana manubri', 'distensioni manubri panca piana', 'flat dumbbell press', 'dumbbell bench press'], 'PETTO', 'Focus: Pettorali e tricipiti', 'chest'), (['panca inclinata manubri', 'incline dumbbell press', 'distensioni manubri inclinata'], 'PETTO (ALTO)', 'Focus: Pettorali superiori e tricipiti', 'chest'), (['chest press', 'press macchina', 'machine chest press', 'horizontal chest press'], 'PETTO', 'Focus: Pettorali e tricipiti', 'chest'), (['chest press inclinata', 'incline chest press'], 'PETTO (ALTO)', 'Focus: Pettorali superiori e tricipiti', 'chest'), (['pec deck', 'peck deck', 'butterfly machine', 'butterfly'], 'PETTO', 'Focus: Pettorali', 'chest'), (['croci manubri', 'dumbbell fly', 'flat dumbbell fly'], 'PETTO', 'Focus: Pettorali', 'chest'), (['croci manubri inclinate', 'incline dumbbell fly'], 'PETTO (ALTO)', 'Focus: Pettorali superiori', 'chest'), (['croci ai cavi', 'cable fly', 'cable crossover', 'crossover cavi'], 'PETTO', 'Focus: Pettorali', 'chest'), (['croci cavi dal basso', 'low cable fly', 'low to high cable fly'], 'PETTO (ALTO)', 'Focus: Pettorali superiori', 'chest'), (['croci cavi dall alto', 'high cable fly', 'high to low cable fly'], 'PETTO', 'Focus: Pettorali', 'chest'), (['dip alle parallele', 'chest dips', 'dips petto', 'dip petto'], 'PETTO', 'Focus: Pettorali e tricipiti', 'chest'), (['push up', 'pushup', 'piegamenti', 'flessioni', 'push-up'], 'PETTO', 'Focus: Pettorali, tricipiti e core', 'chest'), (['incline push up', 'push up inclinati'], 'PETTO', 'Focus: Pettorali', 'chest'), (['decline push up', 'push up declinati'], 'PETTO', 'Focus: Pettorali superiori', 'chest'), (['squeeze press', 'hex press'], 'PETTO', 'Focus: Pettorali', 'chest'), (['lat machine presa larga', 'lat machine larga', 'wide grip lat pulldown', 'wide grip pulldown'], 'DORSO', 'Focus: Gran dorsale e bicipiti', 'back'), (['lat machine presa stretta', 'close grip lat pulldown', 'close grip pulldown'], 'DORSO', 'Focus: Gran dorsale e bicipiti', 'back'), (['lat machine inversa', 'reverse grip lat pulldown', 'supinated lat pulldown'], 'DORSO', 'Focus: Gran dorsale e bicipiti', 'back'), (['lat machine neutra', 'neutral grip lat pulldown'], 'DORSO', 'Focus: Gran dorsale', 'back'), (['trazioni prone', 'pull up', 'pronated pull up', 'pullup'], 'DORSO', 'Focus: Gran dorsale e bicipiti', 'back'), (['trazioni presa larga', 'trazioni larghe', 'wide grip pull up', 'wide grip pullup'], 'DORSO', 'Focus: Gran dorsale', 'back'), (['trazioni supine', 'chin up', 'chinup', 'supinated pull up'], 'DORSO', 'Focus: Dorsali e bicipiti', 'back'), (['trazioni neutre', 'neutral grip pull up'], 'DORSO', 'Focus: Dorsali e bicipiti', 'back'), (['rematore bilanciere', 'rematore con bilanciere', 'barbell row', 'bent over row'], 'DORSO', 'Focus: Dorsali, romboidi e bicipiti', 'back'), (['rematore manubrio', 'rematore con manubrio', 'one arm row', 'dumbbell row'], 'DORSO', 'Focus: Dorsali e romboidi', 'back'), (['chest supported dumbbell row', 'rematore manubri panca inclinata'], 'DORSO', 'Focus: Dorsali e romboidi', 'back'), (['t bar row', 't-bar row', 't bar', 't-bar', 'rematore t bar', 'rematore t-bar'], 'DORSO', 'Focus: Dorsali, romboidi e trapezio', 'back'), (['t bar prona larga', 't-bar prona larga', 't bar presa prona larga', 't-bar presa prona larga', 't bar row wide pronated', 't bar row wide grip', 'tbar prona larga', 'tbar wide grip'], 'DORSO', 'Focus: Dorsali, romboidi e trapezio', 'back'), (['t bar presa stretta', 't-bar presa stretta', 'close grip t bar row'], 'DORSO', 'Focus: Dorsali e romboidi', 'back'), (['pulley basso', 'seated cable row', 'seated row', 'low cable row', 'cable row'], 'DORSO', 'Focus: Dorsali e parte centrale della schiena', 'back'), (['pulley presa stretta', 'close grip seated row'], 'DORSO', 'Focus: Dorsali', 'back'), (['pulley presa larga', 'wide grip seated row'], 'DORSO', 'Focus: Dorsali e romboidi', 'back'), (['rematore macchina', 'machine row', 'machine seated row'], 'DORSO', 'Focus: Dorsali e romboidi', 'back'), (['hammer row', 'hammer strength row'], 'DORSO', 'Focus: Dorsali e romboidi', 'back'), (['pullover cavo', 'cable pullover', 'straight arm pulldown', 'pulldown braccia tese'], 'DORSO', 'Focus: Gran dorsale', 'back'), (['pullover manubrio', 'dumbbell pullover'], 'DORSO', 'Focus: Gran dorsale e petto', 'back'), (['seal row', 'rematore seal'], 'DORSO', 'Focus: Dorsali e romboidi', 'back'), (['meadows row', 'rematore meadows'], 'DORSO', 'Focus: Dorsali e romboidi', 'back'), (['military press', 'overhead press', 'shoulder press bilanciere', 'lento avanti'], 'SPALLE', 'Focus: Deltoidi e tricipiti', 'shoulders'), (['shoulder press', 'spinte manubri spalle', 'press manubri spalle'], 'SPALLE', 'Focus: Deltoidi e tricipiti', 'shoulders'), (['arnold press', 'arnold shoulder press'], 'SPALLE', 'Focus: Deltoide anteriore e laterale', 'shoulders'), (['push press', 'spinta push press'], 'SPALLE', 'Focus: Deltoidi e tricipiti', 'shoulders'), (['alzate laterali', 'lateral raise', 'lateral raises', 'alzate laterali manubri', 'alzate laterali cavi'], 'SPALLE', 'Focus: Deltoide laterale', 'shoulders'), (['alzate frontali', 'front raise', 'front raises', 'alzate frontali manubri', 'alzate frontali cavi'], 'SPALLE', 'Focus: Deltoide anteriore', 'shoulders'), (['alzate posteriori', 'rear delt fly', 'reverse fly', 'croci inverse', 'reverse fly machine'], 'SPALLE', 'Focus: Deltoide posteriore', 'shoulders'), (['face pull', 'face pulls', 'tirate al viso', 'cavo al viso'], 'SPALLE', 'Focus: Deltoide posteriore e cuffia dei rotatori', 'shoulders'), (['tirate al mento', 'upright row', 'upright rows'], 'SPALLE', 'Focus: Deltoidi e trapezio', 'shoulders'), (['y raise', 'y raises', 'alzate a y'], 'SPALLE', 'Focus: Deltoide posteriore e trapezio', 'shoulders'), (['scaption', 'alzate scaption'], 'SPALLE', 'Focus: Deltoidi e cuffia', 'shoulders'), (['handstand push up', 'vertical push up', 'hspu'], 'SPALLE', 'Focus: Deltoidi e tricipiti', 'shoulders'), (['pike push up', 'pike pushup'], 'SPALLE', 'Focus: Deltoidi e tricipiti', 'shoulders'), (['curl bilanciere', 'barbell curl', 'curl con bilanciere'], 'BICIPITI', 'Focus: Bicipiti', 'biceps'), (['curl ez', 'ez curl', 'curl barra ez'], 'BICIPITI', 'Focus: Bicipiti', 'biceps'), (['curl manubri', 'dumbbell curl', 'curl alternato', 'curl alternato manubri'], 'BICIPITI', 'Focus: Bicipiti', 'biceps'), (['curl martello', 'hammer curl', 'hammer curl manubri'], 'BICIPITI', 'Focus: Bicipite e brachiale', 'biceps'), (['curl inclinato', 'incline dumbbell curl', 'incline curl'], 'BICIPITI', 'Focus: Bicipiti, capo lungo', 'biceps'), (['curl concentrato', 'concentration curl'], 'BICIPITI', 'Focus: Bicipiti', 'biceps'), (['curl scott', 'preacher curl', 'preacher bench curl'], 'BICIPITI', 'Focus: Bicipiti', 'biceps'), (['curl al cavo', 'cable curl', 'cable biceps curl'], 'BICIPITI', 'Focus: Bicipiti', 'biceps'), (['bayesian curl', 'curl bayesiano'], 'BICIPITI', 'Focus: Bicipiti, capo lungo', 'biceps'), (['spider curl', 'curl spider'], 'BICIPITI', 'Focus: Bicipiti', 'biceps'), (['zottman curl', 'curl zottman'], 'BICIPITI', 'Focus: Bicipiti e avambracci', 'biceps'), (['reverse curl', 'curl inverso'], 'BICIPITI', 'Focus: Brachiale e avambracci', 'biceps'), (['pushdown corda', 'rope pushdown', 'triceps rope pushdown'], 'TRICIPITI', 'Focus: Tricipiti', 'triceps'), (['pushdown barra', 'straight bar pushdown', 'triceps pushdown'], 'TRICIPITI', 'Focus: Tricipiti', 'triceps'), (['reverse grip pushdown', 'reverse pushdown'], 'TRICIPITI', 'Focus: Tricipiti', 'triceps'), (['french press', 'skull crusher', 'skull crushers', 'lying triceps extension'], 'TRICIPITI', 'Focus: Tricipiti', 'triceps'), (['french press manubri', 'dumbbell skull crusher'], 'TRICIPITI', 'Focus: Tricipiti', 'triceps'), (['estensioni sopra la testa', 'overhead triceps extension', 'overhead extension'], 'TRICIPITI', 'Focus: Tricipiti', 'triceps'), (['cable overhead triceps extension', 'estensione tricipiti cavo'], 'TRICIPITI', 'Focus: Tricipiti', 'triceps'), (['dip tricipiti', 'bench dips', 'dip panca'], 'TRICIPITI', 'Focus: Tricipiti', 'triceps'), (['close grip bench press', 'panca presa stretta'], 'TRICIPITI', 'Focus: Tricipiti e petto', 'triceps'), (['jm press', 'jm press bilanciere'], 'TRICIPITI', 'Focus: Tricipiti', 'triceps'), (['squat', 'back squat', 'squat libero', 'squat bilanciere'], 'GAMBE (QUADRICIPITI)', 'Focus: Quadricipiti e glutei', 'quads'), (['front squat', 'squat frontale'], 'GAMBE (QUADRICIPITI)', 'Focus: Quadricipiti', 'quads'), (['goblet squat', 'squat goblet'], 'GAMBE (QUADRICIPITI)', 'Focus: Quadricipiti e glutei', 'quads'), (['hack squat', 'hack machine', 'squat hack'], 'GAMBE (QUADRICIPITI)', 'Focus: Quadricipiti e glutei', 'quads'), (['leg press', 'pressa', 'pressa 45', 'pressa gambe', 'leg press 45'], 'GAMBE (QUADRICIPITI)', 'Focus: Quadricipiti e glutei', 'quads'), (['leg extension', 'leg extensions', 'estensioni delle gambe', 'estensione gambe'], 'QUADRICIPITI', 'Focus: Quadricipiti', 'quads'), (['affondi', 'affondo', 'lunges', 'walking lunge'], 'GAMBE (QUADRICIPITI)', 'Focus: Quadricipiti e glutei', 'quads'), (['bulgarian split squat', 'squat bulgaro', 'split squat'], 'GAMBE (QUADRICIPITI)', 'Focus: Quadricipiti e glutei', 'quads'), (['step up', 'stepup', 'salita su panca'], 'GAMBE (QUADRICIPITI)', 'Focus: Quadricipiti e glutei', 'quads'), (['sissy squat', 'sissy squat bodyweight'], 'QUADRICIPITI', 'Focus: Quadricipiti', 'quads'), (['spanish squat'], 'QUADRICIPITI', 'Focus: Quadricipiti', 'quads'), (['reverse lunge', 'affondo indietro'], 'GAMBE (QUADRICIPITI)', 'Focus: Quadricipiti e glutei', 'quads'), (['lateral lunge', 'affondo laterale'], 'GAMBE', 'Focus: Quadricipiti, glutei e adduttori', 'quads'), (['stacco rumeno', 'stacchi rumeni', 'romanian deadlift', 'rdl', 'stacco gambe semitese'], 'FEMORALI / GLUTEI', 'Focus: Catena posteriore e glutei', 'hamstrings'), (['stacco gambe tese', 'stiff leg deadlift', 'stiff leg'], 'FEMORALI / GLUTEI', 'Focus: Femorali e glutei', 'hamstrings'), (['stacco sumo', 'sumo deadlift'], 'GLUTEI / FEMORALI', 'Focus: Glutei, femorali e adduttori', 'hamstrings'), (['stacco da terra', 'stacchi da terra', 'deadlift', 'conventional deadlift', 'stacco'], 'SCHIENA / GAMBE', 'Focus: Schiena, glutei e femorali', 'back_legs'), (['leg curl sdraiato', 'lying leg curl', 'prone leg curl'], 'FEMORALI', 'Focus: Femorali', 'hamstrings'), (['leg curl seduto', 'seated leg curl'], 'FEMORALI', 'Focus: Femorali', 'hamstrings'), (['standing leg curl', 'leg curl in piedi'], 'FEMORALI', 'Focus: Femorali', 'hamstrings'), (['hip thrust', 'hip thrust bilanciere'], 'GLUTEI', 'Focus: Glutei', 'hamstrings'), (['glute bridge', 'ponte glutei', 'glute bridge bilanciere'], 'GLUTEI', 'Focus: Glutei', 'hamstrings'), (['kickback', 'kick back', 'glute kickback', 'slanci glutei', 'cable kickback'], 'GLUTEI', 'Focus: Glutei', 'hamstrings'), (['abduzioni', 'abduzione macchina', 'hip abduction', 'abductor machine'], 'GLUTEI', 'Focus: Gluteo medio', 'hamstrings'), (['adduzioni', 'adduzione macchina', 'hip adduction', 'adductor machine'], 'ADDUTTORI', 'Focus: Adduttori', 'hamstrings'), (['good morning', 'good mornings'], 'FEMORALI / GLUTEI', 'Focus: Femorali, glutei e lombari', 'hamstrings'), (['nordic curl', 'nordic hamstring curl'], 'FEMORALI', 'Focus: Femorali', 'hamstrings'), (['glute ham raise', 'ghr'], 'FEMORALI / GLUTEI', 'Focus: Femorali e glutei', 'hamstrings'), (['calf raise', 'calf raises', 'standing calf raise', 'calf in piedi'], 'POLPACCI', 'Focus: Polpacci', 'quads'), (['calf seduto', 'seated calf raise', 'seated calf'], 'POLPACCI', 'Focus: Soleo e polpacci', 'quads'), (['calf press', 'calf press leg press', 'polpacci pressa'], 'POLPACCI', 'Focus: Polpacci', 'quads'), (['crunch', 'crunches', 'addominali', 'addome'], 'ADDOME', 'Focus: Retto addominale', 'chest'), (['crunch ai cavi', 'cable crunch'], 'ADDOME', 'Focus: Retto addominale', 'chest'), (['sit up', 'sit-up', 'situp'], 'ADDOME', 'Focus: Addominali', 'chest'), (['leg raise', 'leg raises', 'hanging leg raise', 'sollevamento gambe'], 'ADDOME', "Focus: Addominali inferiori e flessori dell'anca", 'chest'), (['knee raise', 'hanging knee raise', 'sollevamento ginocchia'], 'ADDOME', 'Focus: Addominali', 'chest'), (['plank', 'front plank'], 'ADDOME', 'Focus: Core', 'chest'), (['side plank', 'plank laterale'], 'ADDOME', 'Focus: Obliqui e core', 'chest'), (['mountain climber', 'mountain climbers'], 'ADDOME', "Focus: Core e flessori dell'anca", 'chest'), (['ab wheel', 'ab rollout', 'rollout addominali'], 'ADDOME', 'Focus: Core e retto addominale', 'chest'), (['pallof press', 'pallof'], 'CORE', 'Focus: Core e obliqui', 'chest'), (['russian twist', 'russian twists', 'torsioni russe'], 'ADDOME', 'Focus: Obliqui', 'chest'), (['dead bug'], 'CORE', 'Focus: Core', 'chest'), (['shrug', 'shrugs', 'scrollate', 'scrollate bilanciere'], 'TRAPEZI', 'Focus: Trapezio superiore', 'back'), (['scrollate manubri', 'dumbbell shrug'], 'TRAPEZI', 'Focus: Trapezio superiore', 'back'), (['farmer walk', 'farmer carry', 'passeggiata del contadino'], 'TRAPEZI / CORE', 'Focus: Trapezio, presa e core', 'back'), (['wrist curl', 'curl polsi', 'flessione polsi'], 'AVAMBRACCI', "Focus: Flessori dell'avambraccio", 'biceps'), (['reverse wrist curl', 'estensione polsi'], 'AVAMBRACCI', "Focus: Estensori dell'avambraccio", 'biceps'), (['dead hang', 'hang alla sbarra'], 'PRESA / AVAMBRACCI', 'Focus: Presa e avambracci', 'back'), (['clean', 'power clean', 'girata al petto'], 'FULL BODY', 'Focus: Catena posteriore, gambe e spalle', 'full_body'), (['clean and press', 'clean press'], 'FULL BODY', 'Focus: Gambe, schiena e spalle', 'full_body'), (['snatch', 'strappo'], 'FULL BODY', 'Focus: Catena posteriore e spalle', 'full_body'), (['thruster', 'thrusters'], 'FULL BODY', 'Focus: Gambe, spalle e core', 'full_body'), (['burpee', 'burpees'], 'FULL BODY', 'Focus: Full body e condizionamento', 'full_body'), (['kettlebell swing', 'kb swing', 'swing kettlebell'], 'FULL BODY', 'Focus: Glutei, femorali e core', 'hamstrings'), (['turkish get up', 'turkish get-up', 'alzata turca'], 'FULL BODY', 'Focus: Spalle, core e gambe', 'shoulders')]

ESERCIZI = ESERCIZI_SCHEDA + CATALOGO_COMPLETO + [
    # ---------------- PETTO ----------------
    ([
        "panca inclinata", "panca 30", "panca 32", "panca 35", "panca 45",
        "incline bench", "incline press", "press inclinata", "chest press inclinata",
        "spinta inclinata", "distensioni inclinate"
    ], "PETTO (ALTO)", "Focus: Pettorali superiori e Tricipiti", "chest"),

    ([
        "panca piana", "flat bench", "flat press", "bench press",
        "chest press", "distensioni su panca", "spinte su panca",
        "panca", "press orizzontale"
    ], "PETTO", "Focus: Pettorali e Tricipiti", "chest"),

    ([
        "croci ai cavi", "croci cavi", "cable fly", "cable crossover",
        "crossover", "croci macchina", "pec deck", "peck deck",
        "butterfly", "croci manubri", "croci con manubri", "croci"
    ], "PETTO", "Focus: Pettorali", "chest"),

    ([
        "dip alle parallele", "dip parallele", "dips", "dip",
        "chest dips", "piegamenti", "push up", "pushup", "flessioni"
    ], "PETTO", "Focus: Pettorali e Tricipiti", "chest"),

    # ---------------- DORSO ----------------
    ([
        "trazioni presa larga", "trazioni larghe", "pull up presa larga",
        "wide grip pull up", "lat machine presa larga", "lat machine larga"
    ], "DORSO", "Focus: Gran Dorsale e Bicipiti", "back"),

    ([
        "lat machine", "lat pulldown", "pulldown", "trazioni",
        "pull up", "chin up", "trazioni supine", "trazioni prone",
        "vertical traction"
    ], "DORSO", "Focus: Gran Dorsale e Bicipiti", "back"),

    ([
        "rematore con bilanciere", "rematore bilanciere", "barbell row",
        "rematore con manubrio", "rematore manubrio", "one arm row",
        "dumbbell row", "rematore", "rowing", "row"
    ], "DORSO", "Focus: Dorsali, Romboidi e Bicipiti", "back"),

    ([
        "pulley basso", "low row", "seated row", "cable row",
        "pulley", "tirate al cavo"
    ], "DORSO", "Focus: Dorsali e Parte centrale della schiena", "back"),

    ([
        "pullover", "pullover ai cavi", "cable pullover", "straight arm pulldown",
        "pulldown braccia tese"
    ], "DORSO", "Focus: Gran Dorsale", "back"),

    ([
        "stacco da terra", "stacchi da terra", "deadlift", "conventional deadlift",
        "sumo deadlift", "stacco sumo", "stacco"
    ], "SCHIENA / GAMBE", "Focus: Schiena, Glutei e Femorali", "back_legs"),

    # ---------------- SPALLE ----------------
    ([
        "lento avanti", "military press", "overhead press", "shoulder press",
        "spinte sopra la testa", "spinte verticali", "arnold press",
        "press con manubri sopra la testa", "press spalle"
    ], "SPALLE", "Focus: Deltoidi e Tricipiti", "shoulders"),

    ([
        "alzate laterali", "lateral raise", "lateral raises",
        "alzate a 90", "alzate laterali ai cavi", "alzate laterali manubri"
    ], "SPALLE", "Focus: Deltoide laterale", "shoulders"),

    ([
        "alzate frontali", "front raise", "front raises",
        "alzate frontali manubri", "alzate frontali ai cavi"
    ], "SPALLE", "Focus: Deltoide anteriore", "shoulders"),

    ([
        "reverse fly", "reverse fly machine", "croci inverse",
        "alzate posteriori", "alzate a busto flesso", "rear delt fly",
        "deltoidi posteriori"
    ], "SPALLE", "Focus: Deltoide posteriore", "shoulders"),

    ([
        "tirate al mento", "upright row", "tirate al mento bilanciere",
        "tirate al mento cavo"
    ], "SPALLE", "Focus: Deltoidi e Trapezio", "shoulders"),

    ([
        "scrollate", "shrug", "shrugs", "scrollate manubri", "scrollate bilanciere"
    ], "TRAPEZI", "Focus: Trapezio", "back"),

    # ---------------- BICIPITI ----------------
    ([
        "curl bilanciere", "barbell curl", "curl con bilanciere",
        "curl ez", "curl barra ez", "ez curl"
    ], "BICIPITI", "Focus: Bicipiti", "biceps"),

    ([
        "curl manubri", "dumbbell curl", "curl alternato",
        "curl alternato manubri", "curl supinato"
    ], "BICIPITI", "Focus: Bicipiti", "biceps"),

    ([
        "hammer curl", "curl martello", "curl a martello", "hammer"
    ], "BICIPITI", "Focus: Bicipite e Brachiale", "biceps"),

    ([
        "curl concentrato", "concentration curl", "curl panca scott",
        "preacher curl", "curl scott", "curl al cavo basso", "cable curl"
    ], "BICIPITI", "Focus: Bicipiti", "biceps"),

    # ---------------- TRICIPITI ----------------
    ([
        "pushdown", "push down", "triceps pushdown", "pushdown corda",
        "pushdown barra", "spinte al cavo per tricipiti"
    ], "TRICIPITI", "Focus: Tricipiti", "triceps"),

    ([
        "french press", "french press manubri", "french press bilanciere",
        "skull crusher", "skull crushers", "estensioni sopra la testa",
        "overhead triceps extension", "estensioni tricipiti"
    ], "TRICIPITI", "Focus: Tricipiti", "triceps"),

    ([
        "dip tricipiti", "bench dips", "dip panca"
    ], "TRICIPITI", "Focus: Tricipiti", "triceps"),

    # ---------------- GAMBE / QUADRICIPITI ----------------
    ([
        "leg extension", "leg extensions", "estensioni delle gambe",
        "estensione gambe", "extension quadricipiti"
    ], "GAMBE (QUADRICIPITI)", "Focus: Quadricipiti", "quads"),

    ([
        "hack squat", "hack machine", "squat hack"
    ], "GAMBE (QUADRICIPITI)", "Focus: Quadricipiti e Glutei", "quads"),

    ([
        "leg press", "pressa", "pressa 45", "pressa gambe",
        "leg press 45"
    ], "GAMBE (QUADRICIPITI)", "Focus: Quadricipiti e Glutei", "quads"),

    ([
        "squat", "back squat", "front squat", "goblet squat",
        "squat libero", "squat bilanciere"
    ], "GAMBE (QUADRICIPITI)", "Focus: Quadricipiti e Glutei", "quads"),

    ([
        "affondi", "affondo", "lunges", "walking lunge",
        "bulgarian split squat", "squat bulgaro", "split squat"
    ], "GAMBE (QUADRICIPITI)", "Focus: Quadricipiti e Glutei", "quads"),

    ([
        "step up", "stepup", "salita su panca"
    ], "GAMBE (QUADRICIPITI)", "Focus: Quadricipiti e Glutei", "quads"),

    # ---------------- FEMORALI / GLUTEI ----------------
    ([
        "stacco rumeno", "stacchi rumeni", "romanian deadlift", "rdl",
        "stacco gambe semitese", "stacco a gambe tese"
    ], "FEMORALI / GLUTEI", "Focus: Catena posteriore e Glutei", "hamstrings"),

    ([
        "leg curl", "leg curl sdraiato", "leg curl seduto",
        "seated leg curl", "lying leg curl", "curl femorali",
        "curl gambe"
    ], "FEMORALI / GLUTEI", "Focus: Femorali", "hamstrings"),

    ([
        "hip thrust", "hip thrust bilanciere", "glute bridge",
        "ponte glutei", "glute bridge bilanciere"
    ], "GLUTEI", "Focus: Glutei", "hamstrings"),

    ([
        "kickback", "kick back", "slanci glutei", "glute kickback",
        "abduzioni", "abduzione macchina", "hip abduction"
    ], "GLUTEI", "Focus: Glutei", "hamstrings"),

    # ---------------- POLPACCI ----------------
    ([
        "calf raise", "calf raises", "calf", "calf machine",
        "calf in piedi", "calf seduto", "seated calf raise",
        "standing calf raise", "polpacci", "polpaccio"
    ], "POLPACCI", "Focus: Polpacci", "quads"),

    # ---------------- ADDOME ----------------
    ([
        "crunch", "crunches", "crunch ai cavi", "cable crunch",
        "addominali", "addome", "sit up", "sit up",
        "leg raise", "leg raises", "sollevamento gambe",
        "hanging leg raise"
    ], "ADDOME", "Focus: Addominali", "chest"),

    ([
        "plank", "side plank", "plank laterale", "mountain climber",
        "mountain climbers"
    ], "ADDOME", "Focus: Core e Addominali", "chest"),
]

def _contiene_variante(nome, variante):
    """
    Match intelligente:
    - frasi complete vengono cercate come sequenze di parole;
    - numeri come 'panca 32' vengono mantenuti;
    - evita che 'panca' venga confusa con 'panca inclinata' perché le regole
      più specifiche sono posizionate prima.
    """
    return variante in nome

def analizza_esercizio(testo):
    nome_originale = str(testo).strip()
    nome_pulito = nome_originale.title()
    nome_low = _normalizza_testo(nome_originale)

    if not nome_low:
        return nome_pulito, "CORPO LIBERO / ALTRO", "Inserisci un esercizio", "full_body"

    # 1) Regole specifiche del catalogo
    for varianti, gruppo, descrizione, target in ESERCIZI:
        if any(_contiene_variante(nome_low, _normalizza_testo(v)) for v in varianti):
            return nome_pulito, gruppo, descrizione, target

    # 2) Fallback per esercizi scritti in forme non previste esattamente.
    # L'ordine è importante.
    fallback = [
        (["panca inclinata", "incline", "petto alto"], "PETTO (ALTO)",
         "Focus: Pettorali superiori e Tricipiti", "chest"),
        (["panca", "petto", "chest", "pec"], "PETTO",
         "Focus: Pettorali e Tricipiti", "chest"),
        (["lat", "dorso", "trazioni", "pulley", "rematore", "row"],
         "DORSO", "Focus: Gran Dorsale e Bicipiti", "back"),
        (["spalle", "shoulder", "alzate", "military", "overhead", "arnold"],
         "SPALLE", "Focus: Deltoidi", "shoulders"),
        (["bicipite", "bicipiti", "bicep", "curl"],
         "BICIPITI", "Focus: Bicipiti", "biceps"),
        (["tricipite", "tricipiti", "tricep", "pushdown"],
         "TRICIPITI", "Focus: Tricipiti", "triceps"),
        (["quadricipite", "quadricipiti", "quad", "squat", "pressa", "leg press"],
         "GAMBE (QUADRICIPITI)", "Focus: Quadricipiti e Glutei", "quads"),
        (["femorale", "femorali", "hamstring", "leg curl", "rumeno"],
         "FEMORALI / GLUTEI", "Focus: Catena posteriore e Glutei", "hamstrings"),
        (["gluteo", "glutei", "glute"], "GLUTEI", "Focus: Glutei", "hamstrings"),
        (["polpaccio", "polpacci", "calf"], "POLPACCI", "Focus: Polpacci", "quads"),
        (["addome", "addominali", "crunch", "plank", "core"],
         "ADDOME", "Focus: Addominali e Core", "chest"),
    ]

    for parole, gruppo, descrizione, target in fallback:
        if any(parola in nome_low for parola in parole):
            return nome_pulito, gruppo, descrizione, target

    return nome_pulito, "CORPO LIBERO / ALTRO", "Esercizio generale di tonificazione", "full_body"

# --- MAPPA MUSCOLARE VETTORIALE ---
from pathlib import Path
import re
import base64

MAPPA_SVG = Path(__file__).resolve().parent / "mappa.svg"

TARGET_KEYWORDS = {
    "chest": ["chest", "pect", "petto"],
    "back": ["back", "lat", "lats", "dorso"],
    "shoulders": ["shoulder", "shoulders", "delt", "deltoid", "spalle"],
    "biceps": ["bicep", "biceps", "bicipiti"],
    "triceps": ["tricep", "triceps", "tricipiti"],
    "quads": ["quad", "quads", "quadriceps", "quadricipiti"],
    "hamstrings": ["hamstring", "hamstrings", "glute", "glutes", "femorali"],
}

OLD_ID_TO_TARGET = {
    "muscle-1": "chest", "muscle-2": "chest",
    "muscle-3": "biceps", "muscle-4": "biceps",
    "muscle-11": "quads", "muscle-12": "quads",
    "muscle-17": "back", "muscle-18": "back",
    "muscle-19": "triceps", "muscle-20": "triceps",
    "muscle-24": "hamstrings", "muscle-25": "hamstrings",
    "muscle-26": "hamstrings", "muscle-27": "hamstrings",
    "muscle-32": "shoulders", "muscle-33": "shoulders",
    "muscle-34": "shoulders", "muscle-35": "shoulders",
}

ANATOMY_KEYWORDS = sum(TARGET_KEYWORDS.values(), [])

def _target_keywords(target_muscle):
    target = str(target_muscle).lower().strip()
    if target == "back_legs":
        return TARGET_KEYWORDS["back"] + TARGET_KEYWORDS["hamstrings"]
    return TARGET_KEYWORDS.get(target, [])

def _is_muscle_tag(tag):
    return bool(
        re.search(r'\bid=["\'](?:muscle-\d+|(?:' + '|'.join(map(re.escape, ANATOMY_KEYWORDS)) + r'))[^"\']*["\']', tag, re.I)
        or re.search(r'\bdata-(?:region|muscle)=', tag, re.I)
    )

def _matches(tag, target):
    id_match = re.search(r'\bid=["\']([^"\']+)["\']', tag, re.I)
    region_match = re.search(r'\bdata-region=["\']([^"\']+)["\']', tag, re.I)
    muscle_match = re.search(r'\bdata-muscle=["\']([^"\']+)["\']', tag, re.I)

    values = [m.group(1).lower() for m in (id_match, region_match, muscle_match) if m]
    keywords = _target_keywords(target)

    if id_match:
        old = OLD_ID_TO_TARGET.get(id_match.group(1).lower())
        if old:
            return old == target or (target == "back_legs" and old in ("back", "hamstrings"))

    return bool(keywords) and any(k in v for k in keywords for v in values)

def _style_svg(svg, target):
    # Tutte le aree muscolari diventano neutre; quelle target diventano rosse.
    pattern = re.compile(r'<(?:path|polygon|ellipse|rect)\b[^>]*>', re.I)

    def repl(match):
        tag = match.group(0)
        if not _is_muscle_tag(tag):
            return tag

        active = _matches(tag, target)
        fill = "#ff4757" if active else "#555a70"
        stroke = "#ffffff" if active else "#303445"
        sw = "2" if active else "0.5"

        tag = re.sub(r'\s+(?:fill|stroke|stroke-width)=["\'][^"\']*["\']', '', tag, flags=re.I)

        if tag.rstrip().endswith("/>"):
            return tag[:-2] + f' fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
        return tag[:-1] + f' fill="{fill}" stroke="{stroke}" stroke-width="{sw}">'

    return pattern.sub(repl, svg)

def render_mappa_muscolare(target_muscle):
    # Render stabile: niente components.html, iframe, JavaScript o CairoSVG.
    if not MAPPA_SVG.is_file():
        st.error(f"❌ mappa.svg non trovata: {MAPPA_SVG}")
        return

    try:
        svg = MAPPA_SVG.read_text(encoding="utf-8")
        svg = re.sub(r'<\\?xml[^>]*\\?>', '', svg, flags=re.I)
        svg = _style_svg(svg, target_muscle)
        svg = re.sub(r'<script\\b.*?</script>', '', svg, flags=re.I | re.S)
        svg = re.sub(r'<style\\b.*?</style>', '', svg, flags=re.I | re.S)
        encoded = base64.b64encode(svg.encode("utf-8")).decode("ascii")

        st.markdown(
            f'''
            <div style="width:100%;display:flex;justify-content:center;align-items:center;padding:4px 0 8px;">
                <img src="data:image/svg+xml;base64,{encoded}"
                     alt="Mappa muscolare"
                     style="width:100%;max-width:360px;height:auto;display:block;" />
            </div>
            ''',
            unsafe_allow_html=True
        )
    except UnicodeDecodeError:
        st.error("❌ mappa.svg non è codificata in UTF-8.")
    except Exception as e:
        st.error(f"❌ Errore caricando mappa.svg: {e}")


# ============================================================
# GYM TRACKER PRO — PREMIUM UI
# ============================================================

giorni_settimana = ["Lunedì", "Martedì", "Mercoledì", "Giovedì",
                    "Venerdì", "Sabato", "Domenica"]

if "tema" not in st.session_state:
    st.session_state.tema = "Scuro"

if "pagina" not in st.session_state:
    st.session_state.pagina = "Allenamento"

tema = st.session_state.tema
dark = tema == "Scuro"

# ---------- DATI ----------
def get_day_rows(giorno):
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, nome_esercizio, gruppo_muscolare, numero_serie,
               ripetizioni, peso, completato
        FROM serie_esercizio
        WHERE giorno = ?
        ORDER BY nome_esercizio, numero_serie
    """, (giorno,))
    rows = cursor.fetchall()
    conn.close()
    return rows

def get_stats(giorno):
    rows = get_day_rows(giorno)
    totale = len(rows)
    completate = sum(1 for r in rows if r[6])
    volume = sum(float(r[5] or 0) for r in rows if r[6])
    esercizi = len(set(r[1] for r in rows))
    return totale, completate, volume, esercizi

def get_week_stats():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*), SUM(completato), SUM(peso * completato) FROM serie_esercizio")
    totale, completate, volume = cursor.fetchone()
    cursor.execute("SELECT COUNT(DISTINCT giorno) FROM serie_esercizio WHERE completato = 1")
    giorni = cursor.fetchone()[0] or 0
    conn.close()
    return totale or 0, completate or 0, volume or 0, giorni

def safe_text(value):
    return str(value).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

# ---------- CSS ----------
if dark:
    BG = "#080B12"
    PANEL = "#111622"
    PANEL2 = "#171D2B"
    TEXT = "#F6F8FC"
    MUTED = "#8D96A8"
    BORDER = "rgba(255,255,255,.08)"
    ACCENT = "#6C63FF"
    ACCENT2 = "#00D4FF"
    GOOD = "#20D98A"
    SOFT = "rgba(108,99,255,.14)"
else:
    BG = "#F4F7FB"
    PANEL = "#FFFFFF"
    PANEL2 = "#F0F3F8"
    TEXT = "#111827"
    MUTED = "#667085"
    BORDER = "rgba(17,24,39,.08)"
    ACCENT = "#5B5FEF"
    ACCENT2 = "#009FE3"
    GOOD = "#12B76A"
    SOFT = "rgba(91,95,239,.10)"

st.markdown(f"""
<style>
    :root {{
        --bg: {BG};
        --panel: {PANEL};
        --panel2: {PANEL2};
        --text: {TEXT};
        --muted: {MUTED};
        --border: {BORDER};
        --accent: {ACCENT};
        --accent2: {ACCENT2};
        --good: {GOOD};
        --soft: {SOFT};
    }}

    .stApp {{
        background:
            radial-gradient(circle at 8% 0%, rgba(108,99,255,.16), transparent 27%),
            radial-gradient(circle at 95% 12%, rgba(0,212,255,.10), transparent 24%),
            var(--bg);
        color: var(--text);
    }}

    [data-testid="stHeader"] {{
        background: transparent;
    }}

    [data-testid="stSidebar"] {{
        background: var(--panel);
        border-right: 1px solid var(--border);
    }}

    [data-testid="stSidebar"] * {{
        color: var(--text);
    }}

    .block-container {{
        max-width: 1180px;
        padding-top: 2.2rem;
        padding-bottom: 4rem;
    }}

    h1, h2, h3, h4, p, label, span {{
        color: var(--text);
    }}

    .hero {{
        border: 1px solid var(--border);
        border-radius: 28px;
        padding: 28px;
        margin-bottom: 18px;
        background:
            linear-gradient(135deg, rgba(108,99,255,.20), rgba(0,212,255,.08)),
            var(--panel);
        box-shadow: 0 18px 55px rgba(0,0,0,.16);
        position: relative;
        overflow: hidden;
    }}

    .hero:after {{
        content: "";
        position: absolute;
        width: 240px;
        height: 240px;
        right: -70px;
        top: -100px;
        border-radius: 50%;
        background: radial-gradient(circle, rgba(108,99,255,.32), transparent 65%);
    }}

    .eyebrow {{
        color: var(--accent2) !important;
        font-size: 12px;
        font-weight: 800;
        letter-spacing: 1.8px;
        text-transform: uppercase;
        margin-bottom: 7px;
    }}

    .hero-title {{
        font-size: clamp(30px, 5vw, 46px);
        line-height: 1.02;
        font-weight: 900;
        letter-spacing: -1.7px;
        margin: 0;
    }}

    .hero-sub {{
        color: var(--muted) !important;
        font-size: 15px;
        margin-top: 10px;
    }}

    .section-title {{
        font-size: 22px;
        font-weight: 850;
        letter-spacing: -.6px;
        margin: 26px 0 12px;
    }}

    .metric-card {{
        background: var(--panel);
        border: 1px solid var(--border);
        border-radius: 20px;
        padding: 18px;
        min-height: 116px;
        box-shadow: 0 10px 30px rgba(0,0,0,.08);
    }}

    .metric-label {{
        color: var(--muted) !important;
        font-size: 12px;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: .8px;
    }}

    .metric-value {{
        color: var(--text) !important;
        font-size: 30px;
        line-height: 1.05;
        font-weight: 900;
        margin-top: 10px;
    }}

    .metric-small {{
        color: var(--muted) !important;
        font-size: 12px;
        margin-top: 5px;
    }}

    .progress-shell {{
        background: var(--panel2);
        border: 1px solid var(--border);
        border-radius: 20px;
        padding: 18px 20px;
        margin-top: 14px;
    }}

    .progress-top {{
        display:flex;
        justify-content:space-between;
        align-items:center;
        gap:12px;
        margin-bottom:10px;
    }}

    .progress-title {{
        font-weight:800;
        color:var(--text) !important;
    }}

    .progress-number {{
        font-weight:900;
        color:var(--accent2) !important;
    }}

    .bar {{
        width:100%;
        height:10px;
        background:var(--panel);
        border-radius:999px;
        overflow:hidden;
        border:1px solid var(--border);
    }}

    .bar > div {{
        height:100%;
        border-radius:999px;
        background:linear-gradient(90deg, var(--accent), var(--accent2));
        box-shadow:0 0 18px rgba(108,99,255,.35);
    }}

    .exercise-card {{
        background: var(--panel);
        border: 1px solid var(--border);
        border-radius: 24px;
        padding: 20px;
        margin: 12px 0;
        box-shadow: 0 10px 34px rgba(0,0,0,.08);
    }}

    .exercise-name {{
        font-size: 20px;
        font-weight: 900;
        letter-spacing: -.4px;
        color: var(--text) !important;
    }}

    .badge {{
        display:inline-block;
        padding:6px 10px;
        border-radius:999px;
        background:var(--soft);
        color:var(--accent2) !important;
        font-size:11px;
        font-weight:850;
        letter-spacing:.4px;
        margin-top:7px;
    }}

    .series-row {{
        display:flex;
        align-items:center;
        justify-content:space-between;
        gap:12px;
        background:var(--panel2);
        border:1px solid var(--border);
        border-radius:16px;
        padding:11px 13px;
        margin-top:8px;
    }}

    .series-done {{
        border-color: rgba(32,217,138,.35);
        background: rgba(32,217,138,.07);
    }}

    .series-label {{
        font-weight:800;
        color:var(--text) !important;
    }}

    .series-meta {{
        color:var(--muted) !important;
        font-size:12px;
    }}

    .nav-title {{
        font-size:12px;
        font-weight:900;
        letter-spacing:1.3px;
        color:var(--muted) !important;
        text-transform:uppercase;
        margin: 4px 0 8px;
    }}

    .tip {{
        border:1px solid var(--border);
        background:linear-gradient(135deg, var(--panel), var(--panel2));
        border-radius:20px;
        padding:17px;
        color:var(--muted) !important;
        font-size:13px;
        line-height:1.5;
        margin-top:15px;
    }}

    .empty {{
        text-align:center;
        padding:44px 20px;
        border:1px dashed var(--border);
        border-radius:24px;
        background:var(--panel);
        color:var(--muted) !important;
    }}

    div[data-testid="stButton"] > button {{
        border-radius:14px;
        border:1px solid var(--border);
        background:var(--panel);
        color:var(--text);
        font-weight:800;
        min-height:42px;
    }}

    div[data-testid="stButton"] > button:hover {{
        border-color:var(--accent);
        color:var(--text);
        box-shadow:0 8px 24px rgba(108,99,255,.15);
    }}

    div[data-testid="stFormSubmitButton"] > button {{
        border:0;
        border-radius:15px;
        min-height:48px;
        font-weight:900;
        background:linear-gradient(90deg, var(--accent), var(--accent2));
        color:white;
    }}

    .stTextInput input, .stNumberInput input, .stSelectbox div[data-baseweb="select"] {{
        border-radius:13px !important;
    }}

    @media (max-width: 700px) {{
        .block-container {{
            padding: 1rem .8rem 3rem;
        }}
        .hero {{
            border-radius:22px;
            padding:22px;
        }}
    }}
</style>
""", unsafe_allow_html=True)

# ---------- SIDEBAR ----------
with st.sidebar:
    st.markdown("## 🔥 Gym Tracker")
    st.caption("Il tuo spazio fitness personale")

    st.markdown('<div class="nav-title">Tema</div>', unsafe_allow_html=True)
    tema_nuovo = st.radio(
        "Tema",
        ["Scuro", "Chiaro"],
        index=0 if tema == "Scuro" else 1,
        horizontal=True,
        label_visibility="collapsed"
    )
    if tema_nuovo != st.session_state.tema:
        st.session_state.tema = tema_nuovo
        st.rerun()

    st.markdown("---")
    st.markdown('<div class="nav-title">Sezione</div>', unsafe_allow_html=True)

    if st.button("🏋️  Allenamento", use_container_width=True):
        st.session_state.pagina = "Allenamento"
        st.rerun()

    if st.button("➕  Aggiungi esercizio", use_container_width=True):
        st.session_state.pagina = "Aggiungi"
        st.rerun()

    st.markdown("---")
    st.caption("Gym Tracker Pro")
    st.caption("Premium training dashboard")

# ---------- HEADER ----------
st.markdown("""
<div class="hero">
    <div class="eyebrow">GYM TRACKER PRO</div>
    <div class="hero-title">Costruisci la tua<br>versione migliore.</div>
    <div class="hero-sub">Allenamenti, progressi e muscoli sotto controllo.</div>
</div>
""", unsafe_allow_html=True)

# ---------- PAGINA AGGIUNGI ----------
if st.session_state.pagina == "Aggiungi":
    st.markdown('<div class="section-title">➕ Nuovo esercizio</div>', unsafe_allow_html=True)
    st.caption("Aggiungilo alla giornata e Gym Tracker riconoscerà automaticamente il gruppo muscolare.")

    with st.form("form_aggiunta_premium", clear_on_submit=True):
        c1, c2 = st.columns(2)
        with c1:
            giorno_scelto = st.selectbox("Giorno", giorni_settimana)
            input_es = st.text_input(
                "Nome esercizio",
                placeholder="Es. Panca inclinata, Stacchi rumeni..."
            )
        with c2:
            ripetizioni = st.text_input("Ripetizioni target", value="8-10")
            num_serie = st.number_input("Numero di serie", min_value=1, max_value=10, value=3)

        st.markdown("### Carico per serie")
        pesi = []
        cols = st.columns(min(int(num_serie), 5))
        for i in range(1, int(num_serie) + 1):
            with cols[(i - 1) % len(cols)]:
                pesi.append(
                    st.number_input(
                        f"S{i} · kg",
                        min_value=0.0,
                        value=20.0,
                        step=0.5,
                        key=f"premium_p_{i}"
                    )
                )

        salva = st.form_submit_button("Salva esercizio", use_container_width=True)

        if salva and input_es.strip():
            nome_es, gruppo, _, _ = analizza_esercizio(input_es)

            conn = sqlite3.connect(DB_NAME)
            cursor = conn.cursor()
            for idx, peso_s in enumerate(pesi, start=1):
                cursor.execute(
                    """INSERT INTO serie_esercizio
                    (giorno, nome_esercizio, gruppo_muscolare, numero_serie,
                     ripetizioni, peso, completato)
                    VALUES (?, ?, ?, ?, ?, ?, 0)""",
                    (giorno_scelto, nome_es, gruppo, idx, ripetizioni, peso_s)
                )
            conn.commit()
            conn.close()

            st.success(f"✓ {nome_es} aggiunto a {giorno_scelto} · {gruppo}")
            st.session_state.pagina = "Allenamento"
            st.rerun()

    st.markdown("""
    <div class="tip">
        💡 <b>Riconoscimento intelligente:</b> puoi scrivere varianti come
        “Panca 32°”, “Panca inclinata manubri”, “Curl martello”, “Pushdown corda”
        o “Stacchi rumeni”. Gym Tracker assegna automaticamente il target muscolare.
    </div>
    """, unsafe_allow_html=True)

# ---------- PAGINA ALLENAMENTO ----------
else:
    giorno_attivo = st.selectbox(
        "Giornata",
        giorni_settimana,
        key="sel_giorno_premium"
    )

    totale, completate, volume, esercizi_count = get_stats(giorno_attivo)
    week_tot, week_done, week_volume, week_days = get_week_stats()

    percent = int(round((completate / totale) * 100)) if totale else 0
    week_percent = int(round((week_done / week_tot) * 100)) if week_tot else 0

    st.markdown(f'<div class="section-title">Il tuo allenamento · {giorno_attivo}</div>', unsafe_allow_html=True)

    m1, m2, m3, m4 = st.columns(4)
    metrics = [
        ("SERIE", str(totale), "programmate"),
        ("COMPLETATE", str(completate), f"{percent}% del workout"),
        ("VOLUME", f"{volume:.0f}", "kg completati"),
        ("ESERCIZI", str(esercizi_count), "movimenti")
    ]
    for col, (label, value, small) in zip([m1, m2, m3, m4], metrics):
        with col:
            st.markdown(f"""
            <div class="metric-card">
                <div class="metric-label">{label}</div>
                <div class="metric-value">{value}</div>
                <div class="metric-small">{small}</div>
            </div>
            """, unsafe_allow_html=True)

    st.markdown(f"""
    <div class="progress-shell">
        <div class="progress-top">
            <div class="progress-title">Progressione workout</div>
            <div class="progress-number">{percent}%</div>
        </div>
        <div class="bar"><div style="width:{percent}%"></div></div>
    </div>
    """, unsafe_allow_html=True)

    st.markdown(f"""
    <div class="progress-shell">
        <div class="progress-top">
            <div class="progress-title">Obiettivo settimanale</div>
            <div class="progress-number">{week_done}/{week_tot} serie</div>
        </div>
        <div class="bar"><div style="width:{week_percent}%"></div></div>
        <div class="metric-small" style="margin-top:9px;">
            {week_days}/7 giorni con attività · {week_volume:.0f} kg di volume completato
        </div>
    </div>
    """, unsafe_allow_html=True)

    rows = get_day_rows(giorno_attivo)

    if not rows:
        st.markdown("""
        <div class="empty">
            <div style="font-size:42px;">🏋️</div>
            <h3>Nessun esercizio ancora</h3>
            <div>Aggiungi il primo esercizio per iniziare a costruire la tua scheda.</div>
        </div>
        """, unsafe_allow_html=True)
        if st.button("➕ Aggiungi il primo esercizio", use_container_width=True):
            st.session_state.pagina = "Aggiungi"
            st.rerun()
    else:
        # Raggruppamento per esercizio
        gruppi = {}
        for row in rows:
            gruppi.setdefault(row[1], []).append(row)

        for nome_es, serie in gruppi.items():
            _, gruppo, desc, svg_target = analizza_esercizio(nome_es)
            done_ex = sum(1 for r in serie if r[6])
            total_ex = len(serie)

            st.markdown('<div class="exercise-card">', unsafe_allow_html=True)
            left, right = st.columns([1.55, 1], gap="large")

            with left:
                st.markdown(f'<div class="exercise-name">🏋️ {safe_text(nome_es)}</div>', unsafe_allow_html=True)
                st.markdown(f'<div class="badge">{safe_text(gruppo)}</div>', unsafe_allow_html=True)
                st.caption(desc)

                for riga in serie:
                    # riga = id, nome, gruppo, numero_serie, ripetizioni, peso, completato
                    s_id, _, _, numero_serie, reps, peso_att, fatto_db = riga
                    cls = "series-row series-done" if fatto_db else "series-row"

                    st.markdown(f"""
                    <div class="{cls}">
                        <div>
                            <div class="series-label">
                                {'✓ ' if fatto_db else ''}Serie {numero_serie}
                            </div>
                            <div class="series-meta">Target · {safe_text(reps)} ripetizioni</div>
                        </div>
                        <div style="font-weight:900;color:var(--text);">{float(peso_att):g} kg</div>
                    </div>
                    """, unsafe_allow_html=True)

                    c1, c2 = st.columns([2, 1])
                    with c1:
                        n_peso = st.number_input(
                            f"Peso serie {numero_serie}",
                            min_value=0.0,
                            value=float(peso_att),
                            step=0.5,
                            key=f"premium_weight_{s_id}",
                            label_visibility="collapsed"
                        )
                        if n_peso != float(peso_att):
                            conn = sqlite3.connect(DB_NAME)
                            cursor = conn.cursor()
                            cursor.execute(
                                "UPDATE serie_esercizio SET peso = ? WHERE id = ?",
                                (n_peso, s_id)
                            )
                            conn.commit()
                            conn.close()

                    with c2:
                        check = st.checkbox(
                            "Completata",
                            value=bool(fatto_db),
                            key=f"premium_chk_{s_id}"
                        )
                        if check != bool(fatto_db):
                            conn = sqlite3.connect(DB_NAME)
                            cursor = conn.cursor()
                            cursor.execute(
                                "UPDATE serie_esercizio SET completato = ? WHERE id = ?",
                                (1 if check else 0, s_id)
                            )
                            conn.commit()
                            conn.close()
                            st.rerun()

            with right:
                render_mappa_muscolare(svg_target)
                st.markdown(
                    f'<div style="text-align:center;color:var(--muted);font-size:12px;margin-top:-4px;">'
                    f'{done_ex}/{total_ex} serie completate</div>',
                    unsafe_allow_html=True
                )

            st.markdown('</div>', unsafe_allow_html=True)

            b1, b2 = st.columns(2)
            with b1:
                if st.button(f"🗑️ Rimuovi {nome_es}", key=f"premium_del_{giorno_attivo}_{nome_es}", use_container_width=True):
                    conn = sqlite3.connect(DB_NAME)
                    cursor = conn.cursor()
                    cursor.execute(
                        "DELETE FROM serie_esercizio WHERE giorno = ? AND nome_esercizio = ?",
                        (giorno_attivo, nome_es)
                    )
                    conn.commit()
                    conn.close()
                    st.rerun()
            with b2:
                st.caption("Target muscolare evidenziato sulla mappa.")

        st.markdown("---")
        r1, r2 = st.columns(2)
        with r1:
            if st.button("➕ Aggiungi esercizio", use_container_width=True):
                st.session_state.pagina = "Aggiungi"
                st.rerun()
        with r2:
            if st.button(f"↺ Resetta {giorno_attivo}", use_container_width=True):
                conn = sqlite3.connect(DB_NAME)
                cursor = conn.cursor()
                cursor.execute(
                    "UPDATE serie_esercizio SET completato = 0 WHERE giorno = ?",
                    (giorno_attivo,)
                )
                conn.commit()
                conn.close()
                st.rerun()
