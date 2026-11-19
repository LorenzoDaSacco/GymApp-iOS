import Foundation
import Combine
import CoreBluetooth

/// Opt-in connection to the standard BLE Heart Rate service of Nilox ONAIR.
/// Uses Core Bluetooth restoration and bluetooth-central background mode.
/// iOS can still interrupt delivery; intervals with no reading remain empty.
final class HeartRateMonitor: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    /// A Core Bluetooth identifier is specific to iOS, not the hardware MAC seen on Windows.
    struct DeviceOption: Identifiable, Equatable {
        let id: UUID
        let name: String
        let rssi: Int?
        let advertisesHeartRate: Bool
        let alreadyConnected: Bool
    }

    enum Connection: Equatable {
        case disabled, bluetoothOff, permissionDenied, searching, connecting, listening, notFound, interrupted, failed
        case noHeartService, pairingRequired
        var title: String {
            switch self {
            case .disabled: return "Monitoraggio disattivato"
            case .bluetoothOff: return "Attiva il Bluetooth"
            case .permissionDenied: return "Autorizza il Bluetooth nelle Impostazioni"
            case .searching: return "Cerco ONAIR…"
            case .connecting: return "Connessione ONAIR…"
            case .listening: return "ONAIR connesso · in ascolto"
            case .notFound: return "ONAIR non trovato"
            case .interrupted: return "Connessione interrotta · riconnessione…"
            case .failed: return "Impossibile leggere il sensore"
            case .noHeartService: return "Questo dispositivo non trasmette i battiti in modo standard"
            case .pairingRequired: return "Accetta l'associazione Bluetooth richiesta da iOS"
            }
        }
    }

    @Published private(set) var enabled: Bool
    @Published private(set) var connection: Connection = .disabled
    @Published private(set) var latestBPM: Int?
    @Published private(set) var latestReadingAt: Date?
    @Published private(set) var buckets: [HeartRateBucket] = []
    @Published private(set) var storageError: String?
    @Published private(set) var detectedDevices: [DeviceOption] = []
    /// Nome del bracciale selezionato/collegato. nil finché non ne è stato scelto uno.
    @Published private(set) var connectedDeviceName: String?

    /// Etichetta per i messaggi: ONAIR (o nessun dispositivo ancora scelto) lascia i testi originali,
    /// qualsiasi altro bracciale usa il proprio nome al posto di «ONAIR».
    private var deviceLabel: String? {
        guard let name = connectedDeviceName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty, !name.localizedCaseInsensitiveContains("ONAIR") else { return nil }
        return name
    }
    private func neutral(_ text: String) -> String {
        guard let label = deviceLabel else { return text }
        return text.replacingOccurrences(of: "ONAIR", with: label)
    }
    /// Stato di connessione già adattato al bracciale in uso.
    var statusTitle: String { neutral(connection.title) }

    @Published private(set) var workoutReadings: [WorkoutHeartReading] = []
    @Published private(set) var workoutRecording = false
    @Published private(set) var workoutDiagnostic: String = "Sensore non ancora verificato"
    private var workoutStartSequence = 0
    private var workoutStartedAt: Date?
    @Published private(set) var liveStatus = "In attesa del sensore"
    private var measurementCharacteristic: CBCharacteristic?
    private var watchdogGeneration = 0
    private var recoveryAttempts = 0
    private var lastWorkoutBPMAt: Date?


    func beginWorkoutRecording() {
        workoutReadings = []
        workoutStartedAt = Date()
        workoutRecording = true
        lastWorkoutBPMAt = nil
        recoveryAttempts = 0
        // Senza bracciale (mai collegato e monitoraggio spento) l'allenamento funziona lo stesso:
        // niente scansione Bluetooth, solo un messaggio informativo al posto dei battiti.
        let hasBand = enabled || UserDefaults.standard.string(forKey: Self.peripheralKey) != nil
        guard hasBand else {
            liveStatus = "Nessun bracciale collegato"
            workoutDiagnostic = "Nessun bracciale collegato: l'allenamento prosegue senza battiti. Per usarlo, collegalo dalla scheda Cuore."
            return
        }
        liveStatus = "Connessione e ricezione BPM in corso…"
        workoutDiagnostic = "Connessione al bracciale in corso…"
        if !enabled { start() } else { connectIfPossible() }
        startWorkoutWatchdog()
        workoutStartSequence += 1
        let sequence = workoutStartSequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self, self.workoutRecording, self.workoutStartSequence == sequence,
                  self.workoutReadings.isEmpty else { return }
            self.workoutDiagnostic = self.neutral(self.connection == .listening
                ? "ONAIR connesso, ma non trasmette BPM. Potrebbe richiedere un comando proprietario."
                : "ONAIR non sta inviando BPM. Controlla connessione e permessi Bluetooth.")
        }
    }

    func endWorkoutRecording() -> [WorkoutHeartReading] {
        workoutRecording = false
        watchdogGeneration += 1
        workoutStartSequence += 1
        workoutStartedAt = nil
        return workoutReadings
    }

    /// Ripristina le notifiche GATT se la connessione resta silenziosa.
    /// Non sostituisce un eventuale comando proprietario per accendere il sensore.
    private func startWorkoutWatchdog() {
        watchdogGeneration += 1
        let generation = watchdogGeneration
        scheduleWorkoutCheck(generation)
    }

    private func scheduleWorkoutCheck(_ generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self, self.workoutRecording, self.watchdogGeneration == generation else { return }
            let fresh = self.lastWorkoutBPMAt.map { Date().timeIntervalSince($0) < 15 } ?? false
            if fresh {
                self.liveStatus = "BPM ricevuti dal bracciale"
            } else if self.connection == .listening {
                self.liveStatus = self.neutral("ONAIR connesso, ma non invia battiti. Riprovo la ricezione…")
                if self.recoveryAttempts < 3, let device = self.peripheral,
                   device.state == .connected, let characteristic = self.measurementCharacteristic {
                    self.recoveryAttempts += 1
                    device.setNotifyValue(false, for: characteristic)
                    // La riattivazione viene completata nel callback didUpdateNotificationStateFor.
                } else if self.recoveryAttempts >= 3 {
                    self.liveStatus = "ONAIR connesso ma senza BPM: probabile avvio sensore richiesto dall'app ufficiale"
                }
            } else {
                self.liveStatus = self.neutral("ONAIR non ancora pronto: " + self.connection.title)
                if self.recoveryAttempts < 3 {
                    self.recoveryAttempts += 1
                    self.connectIfPossible()
                }
            }
            self.scheduleWorkoutCheck(generation)
        }
    }

    private static let enabledKey = "gymapp.heart.enabled.v1"
    private static let peripheralKey = "gymapp.heart.peripheralUUID.v1"
    private static let restorationID = "com.gymtrackerpro.onair.central.v1"
    private static let serviceID = CBUUID(string: "180D")
    private static let measurementID = CBUUID(string: "2A37")

    /// Servizi presenti praticamente su ogni dispositivo BLE: permettono di elencare anche i bracciali
    /// già collegati a iOS (ad esempio dall'app del produttore) che non annunciano il servizio cardiaco.
    private static let commonServiceIDs = ["1800", "1801", "180A", "180F"].map { CBUUID(string: $0) }
    private static let wearableHints = [
        "band", "watch", "fit", "amazfit", "zepp", "huawei", "honor", "xiaomi", "redmi", "garmin", "polar",
        "wahoo", "coospo", "magene", "scosche", "tickr", "whoop", "suunto", "coros", "galaxy", "gear", "oppo",
        "realme", "oneplus", "withings", "ticwatch", "bip", "gts", "gtr", "hrm", "heart", "pulse", "cardio",
        "strap", "smart", "mi "
    ]
    static func looksLikeWearable(_ name: String) -> Bool {
        let lower = name.lowercased()
        return wearableHints.contains { lower.contains($0) }
    }

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var scannedPeripherals: [UUID: CBPeripheral] = [:]
    private var scanSequence = 0
    private var lastDiskWrite = Date.distantPast

    private static var storageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("NiloxHeartHistory-v1.json")
    }

    override init() {
        enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        super.init()
        loadHistory()
        central = CBCentralManager(delegate: self, queue: .main, options: [
            CBCentralManagerOptionRestoreIdentifierKey: Self.restorationID,
            CBCentralManagerOptionShowPowerAlertKey: false
        ])
    }

    func start() {
        enabled = true
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        connectIfPossible()
    }

    func stop() {
        enabled = false
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
        stopScanning()
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        measurementCharacteristic = nil
        watchdogGeneration += 1
        connection = .disabled
        saveHistory()
    }

    /// Re-attempt discovery if an old Core Bluetooth device identifier is no longer valid.
    func searchAgain() {
        guard enabled else { return }
        stopScanning()
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        connectedDeviceName = nil
        UserDefaults.standard.removeObject(forKey: Self.peripheralKey)
        connectIfPossible()
    }

    /// Used when the band does not advertise the exact local name ONAIR.
    /// Never writes to the selected device: only discovers the standard heart-rate service.
    func selectDevice(_ identifier: UUID) {
        guard enabled, central.state == .poweredOn,
              let selected = scannedPeripherals[identifier] else { return }
        stopScanning()
        if let peripheral, peripheral.identifier != selected.identifier {
            central.cancelPeripheralConnection(peripheral)
        }
        attach(selected)
        connection = .connecting
        central.connect(selected, options: nil)
    }

    func saveHistory() {
        guard storageError == nil else { return } // Never overwrite unreadable existing history.
        do {
            let url = Self.storageURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoded = try JSONEncoder().encode(buckets)
            try encoded.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
            lastDiskWrite = Date()
        } catch {
            storageError = "Impossibile salvare lo storico: \(error.localizedDescription)"
        }
    }

    func summary(for date: Date) -> HeartRateDaySummary {
        HeartRateHistory.summary(for: date, buckets: buckets)
    }

    private func loadHistory() {
        let url = Self.storageURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            buckets = try JSONDecoder().decode([HeartRateBucket].self, from: Data(contentsOf: url))
            buckets.sort { $0.slotStart < $1.slotStart }
            if let last = buckets.last {
                latestBPM = last.lastBPM
                latestReadingAt = last.lastReceivedAt
            }
        } catch {
            storageError = "Storico cardiaco non leggibile: \(error.localizedDescription). Non verrà sovrascritto."
        }
    }

    private func connectIfPossible() {
        guard enabled else { return }
        switch central.state {
        case .poweredOn:
            if peripheral?.state == .connected {
                connection = .connecting
                peripheral?.discoverServices([Self.serviceID])
                return
            }
            if let raw = UserDefaults.standard.string(forKey: Self.peripheralKey),
               let uuid = UUID(uuidString: raw),
               let remembered = central.retrievePeripherals(withIdentifiers: [uuid]).first {
                attach(remembered)
                connection = .connecting
                central.connect(remembered, options: nil)
            } else {
                startScanning()
            }
        case .unauthorized: connection = .permissionDenied
        case .poweredOff: connection = .bluetoothOff
        default: connection = .connecting
        }
    }

    private func attach(_ device: CBPeripheral) {
        if peripheral?.identifier != device.identifier { measurementCharacteristic = nil }
        peripheral = device
        device.delegate = self
        let known = [device.name, detectedDevices.first(where: { $0.id == device.identifier })?.name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty && !$0.hasPrefix("Senza nome") })
        connectedDeviceName = known ?? "bracciale"
        // Remember only after the standard heart-rate service is actually verified.
    }

    private func recordCandidate(_ device: CBPeripheral, advertisedName: String?,
                                 rssi: Int?, advertisesHeartRate: Bool = false,
                                 alreadyConnected: Bool = false) {
        scannedPeripherals[device.identifier] = device
        let name = [advertisedName, device.name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
            ?? "Senza nome · \(device.identifier.uuidString.suffix(6))"
        let entry = DeviceOption(id: device.identifier, name: name, rssi: rssi,
                                 advertisesHeartRate: advertisesHeartRate,
                                 alreadyConnected: alreadyConnected)
        if let index = detectedDevices.firstIndex(where: { $0.id == entry.id }) {
            // Preserve signal/service info if a later advertisement is less informative.
            let previous = detectedDevices[index]
            detectedDevices[index] = DeviceOption(
                id: entry.id, name: entry.name,
                rssi: entry.rssi ?? previous.rssi,
                advertisesHeartRate: entry.advertisesHeartRate || previous.advertisesHeartRate,
                alreadyConnected: entry.alreadyConnected || previous.alreadyConnected)
        } else {
            detectedDevices.append(entry)
        }
        detectedDevices.sort {
            let l = $0.name.localizedCaseInsensitiveContains("ONAIR") ? 1 : 0
            let r = $1.name.localizedCaseInsensitiveContains("ONAIR") ? 1 : 0
            if l != r { return l > r }
            if $0.advertisesHeartRate != $1.advertisesHeartRate { return $0.advertisesHeartRate }
            // In una palestra affollata i bracciali devono salire in cima, prima di TV, beacon e altro.
            let lw = Self.looksLikeWearable($0.name), rw = Self.looksLikeWearable($1.name)
            if lw != rw { return lw }
            let ln = $0.name.hasPrefix("Senza nome"), rn = $1.name.hasPrefix("Senza nome")
            if ln != rn { return !ln }
            return ($0.rssi ?? -110) > ($1.rssi ?? -110)
        }
        if detectedDevices.count > 40 {
            detectedDevices = Array(detectedDevices.prefix(40))
        }
    }

    private func startScanning() {
        guard enabled, central.state == .poweredOn else { return }
        stopScanning()
        connection = .searching
        detectedDevices = []
        scannedPeripherals = [:]
        scanSequence += 1
        let thisScan = scanSequence
        // iOS can already have a GATT connection to ONAIR through another app.
        // In that case it may stop advertising and never appear in a BLE scan.
        // retrieveConnectedPeripherals finds *system-connected* heart-rate peripherals.
        let heartDevices = central.retrieveConnectedPeripherals(withServices: [Self.serviceID])
        for device in heartDevices {
            recordCandidate(device, advertisedName: nil, rssi: nil,
                            advertisesHeartRate: true, alreadyConnected: true)
        }
        // Qualsiasi altro bracciale già collegato a iOS compare comunque nell'elenco.
        for device in central.retrieveConnectedPeripherals(withServices: Self.commonServiceIDs) {
            recordCandidate(device, advertisedName: nil, rssi: nil,
                            advertisesHeartRate: false, alreadyConnected: true)
        }
        // ONAIR ha la precedenza; altrimenti, se iOS ha un solo sensore cardiaco collegato
        // (il tuo), lo usiamo direttamente. Con più candidati scegli tu dall'elenco.
        if let onair = heartDevices.first(where: { ($0.name ?? "").localizedCaseInsensitiveContains("ONAIR") })
            ?? (heartDevices.count == 1 ? heartDevices.first : nil) {
            attach(onair)
            connection = .connecting
            central.connect(onair, options: nil)
            return
        }
        // This device may not advertise 180D. Scan without a filter while app is open.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        DispatchQueue.main.asyncAfter(deadline: .now() + 40) { [weak self] in
            guard let self, self.enabled, self.scanSequence == thisScan, self.central.isScanning else { return }
            self.central.stopScan()
            self.connection = .notFound
        }
    }

    private func stopScanning() {
        scanSequence += 1
        if central?.isScanning == true { central.stopScan() }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if enabled { connectIfPossible() }
        else { connection = .disabled }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard enabled else { return }
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let restored = peripherals.first {
            attach(restored)
            if restored.state == .connected {
                connection = .connecting
                restored.discoverServices([Self.serviceID])
            } else {
                connection = .interrupted
                central.connect(restored, options: nil)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover device: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard enabled else { return }
        let advertisedName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? device.name ?? ""
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        recordCandidate(device, advertisedName: advertisedName, rssi: RSSI.intValue,
                        advertisesHeartRate: services.contains(Self.serviceID))
        let knownUUID = UserDefaults.standard.string(forKey: Self.peripheralKey)
        guard advertisedName.localizedCaseInsensitiveContains("ONAIR") ||
                device.identifier.uuidString == knownUUID else { return }
        stopScanning()
        attach(device)
        connection = .connecting
        central.connect(device, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect device: CBPeripheral) {
        guard enabled else { central.cancelPeripheralConnection(device); return }
        attach(device)
        connection = .connecting
        device.discoverServices([Self.serviceID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect device: CBPeripheral, error: Error?) {
        guard enabled else { return }
        connection = .failed
        // A stale device can be recovered with the explicit "Search again" action.
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral device: CBPeripheral,
                        error: Error?) {
        guard enabled else { return }
        connection = .interrupted
        // A pending connection is managed by iOS and can be restored in background.
        central.connect(device, options: nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard enabled else { return }
        guard error == nil else { connection = .failed; return }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceID }) else {
            // Il bracciale non espone il servizio cardiaco standard (180D): di solito va attivata
            // sul bracciale la funzione «trasmetti frequenza cardiaca» / «heart rate broadcast».
            connection = .noHeartService
            return
        }
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Self.peripheralKey)
        peripheral.discoverCharacteristics([Self.measurementID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard enabled else { return }
        guard error == nil else { connection = .failed; return }
        // Alcuni bracciali usano indicate invece di notify: sono entrambi validi per 2A37.
        guard let char = service.characteristics?.first(where: { $0.uuid == Self.measurementID }),
              char.properties.contains(.notify) || char.properties.contains(.indicate) else {
            connection = .noHeartService
            return
        }
        measurementCharacteristic = char
        peripheral.setNotifyValue(true, for: char)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard enabled, characteristic.uuid == Self.measurementID else { return }
        if error == nil && !characteristic.isNotifying && workoutRecording {
            peripheral.setNotifyValue(true, for: characteristic)
            return
        }
        if let error = error as NSError?,
           error.domain == CBATTErrorDomain,
           error.code == CBATTError.insufficientAuthentication.rawValue
            || error.code == CBATTError.insufficientEncryption.rawValue {
            // Il bracciale richiede l'associazione: iOS mostra la richiesta, poi riproviamo.
            connection = .pairingRequired
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                guard let self, self.enabled, self.connection == .pairingRequired,
                      self.peripheral?.identifier == peripheral.identifier else { return }
                peripheral.setNotifyValue(true, for: characteristic)
            }
            return
        }
        connection = error == nil && characteristic.isNotifying ? .listening : .failed
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        // Alcuni bracciali pubblicano il servizio cardiaco solo dopo l'associazione.
        guard enabled else { return }
        peripheral.discoverServices([Self.serviceID])
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard enabled, error == nil, characteristic.uuid == Self.measurementID,
              let data = characteristic.value, data.count >= 2 else { return }
        // Bluetooth Heart Rate Measurement characteristic: flags + 8- or 16-bit BPM.
        let is16Bit = (data[0] & 0x01) != 0
        guard data.count >= (is16Bit ? 3 : 2) else { return }
        let bpm: Int = is16Bit ? Int(data[1]) | (Int(data[2]) << 8) : Int(data[1])
        guard (30...240).contains(bpm) else { return }
        let now = Date()
        latestBPM = bpm
        latestReadingAt = now
        if workoutRecording {
            lastWorkoutBPMAt = now
            liveStatus = "BPM ricevuti dal bracciale"
            workoutDiagnostic = "BPM ricevuti correttamente da ONAIR"
            recoveryAttempts = 0
            workoutReadings.append(WorkoutHeartReading(at: now, bpm: bpm))
        }
        let previousSlot = buckets.last?.slotStart
        HeartRateHistory.record(bpm: bpm, at: now, in: &buckets)
        // Save first reading of each interval immediately, then at most every 30s.
        if previousSlot != HeartRateHistory.slot(for: now) || now.timeIntervalSince(lastDiskWrite) >= 30 {
            saveHistory()
        }
    }
}
