
import Foundation

struct ExerciseRecognition {
    let group: String
    let focus: String
    let target: MuscleTarget
}

enum ExerciseRecognizer {
    /// True when the exercise belongs to the built-in personal/gym registry.
    /// Generic recognition is still available, but unknown names ask the user to choose a muscle.
    static func isKnownExercise(_ raw: String) -> Bool {
        let s = normalize(raw)
        let registry = [
            // Registro personale
            "spinte manubri panca 32", "lat pulldown", "chest press", "t bar prona larga",
            "alzate laterali", "push down asta curva", "curl cavo basso", "leg extension",
            "leg press 45", "leg curl sdraiato", "adduttori", "calf machine",
            "panca piana bilanciere", "rematore bilanciere", "lento avanti manubri panca 71",
            "rowing", "stacchi rumeni manubri", "leg curl seduto", "arm curl", "french press manubri",
            // Registro generico riconosciuto automaticamente
            "panca inclinata", "panca piana", "lat machine", "rematore", "lento avanti",
            "alzate", "curl", "pushdown", "french press", "leg press", "leg extension",
            "leg curl", "stacco"
        ]
        return registry.contains(where: { s.contains($0) })
    }

    static func recognize(_ raw: String) -> ExerciseRecognition {
        let s = normalize(raw)
        let personal: [(String,String,String,MuscleTarget)] = [
            ("spinte manubri panca 32","PETTO (ALTO)","Pettorali superiori e tricipiti",.chest),
            ("lat pulldown","DORSO","Gran dorsale e bicipiti",.back),
            ("chest press","PETTO","Pettorali e tricipiti",.chest),
            ("t bar prona larga","DORSO","Dorsali, romboidi e trapezio",.back),
            ("alzate laterali","SPALLE","Deltoide laterale",.shoulders),
            ("push down asta curva","TRICIPITI","Tricipiti",.triceps),
            ("curl cavo basso","BICIPITI","Bicipiti",.biceps),
            ("leg extension","QUADRICIPITI","Quadricipiti",.quads),
            ("leg press 45","GAMBE (QUADRICIPITI)","Quadricipiti e glutei",.quads),
            ("leg curl sdraiato","FEMORALI","Femorali",.hamstrings),
            ("adduttori","ADDUTTORI","Adduttori",.hamstrings),
            ("calf machine","POLPACCI","Polpacci",.quads),
            ("panca piana bilanciere","PETTO","Pettorali e tricipiti",.chest),
            ("rematore bilanciere","DORSO","Dorsali, romboidi e bicipiti",.back),
            ("lento avanti manubri panca 71","SPALLE","Deltoidi e tricipiti",.shoulders),
            ("rowing","DORSO","Dorsali e romboidi",.back),
            ("stacchi rumeni manubri","FEMORALI / GLUTEI","Catena posteriore e glutei",.hamstrings),
            ("leg curl seduto","FEMORALI","Femorali",.hamstrings),
            ("arm curl","BICIPITI","Bicipiti",.biceps),
            ("french press manubri","TRICIPITI","Tricipiti",.triceps)
        ]
        for (pattern,g,f,t) in personal where s.contains(pattern) { return .init(group:g, focus:"Focus: \(f) · Scheda personale", target:t) }

        let generic: [(String,String,String,MuscleTarget)] = [
            ("panca inclinata","PETTO (ALTO)","Pettorali superiori e tricipiti",.chest),
            ("panca piana","PETTO","Pettorali e tricipiti",.chest),
            ("chest press","PETTO","Pettorali e tricipiti",.chest),
            ("lat machine","DORSO","Gran dorsale e bicipiti",.back),
            ("lat pulldown","DORSO","Gran dorsale e bicipiti",.back),
            ("rematore","DORSO","Dorsali, romboidi e bicipiti",.back),
            ("rowing","DORSO","Dorsali e romboidi",.back),
            ("lento avanti","SPALLE","Deltoidi e tricipiti",.shoulders),
            ("alzate","SPALLE","Deltoidi",.shoulders),
            ("curl","BICIPITI","Bicipiti",.biceps),
            ("pushdown","TRICIPITI","Tricipiti",.triceps),
            ("french press","TRICIPITI","Tricipiti",.triceps),
            ("leg press","GAMBE (QUADRICIPITI)","Quadricipiti e glutei",.quads),
            ("leg extension","QUADRICIPITI","Quadricipiti",.quads),
            ("leg curl","FEMORALI","Femorali",.hamstrings),
            ("stacco","FEMORALI / GLUTEI","Catena posteriore e glutei",.hamstrings)
        ]
        for (pattern,g,f,t) in generic where s.contains(pattern) { return .init(group:g, focus:"Focus: \(f)", target:t) }
        return .init(group:"ALTRO", focus:"Gruppo muscolare da verificare", target:.fullBody)
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }
}
