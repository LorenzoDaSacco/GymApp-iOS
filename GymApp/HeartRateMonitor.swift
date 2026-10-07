import Foundation
import Combine
import CoreBluetooth

/// Opt-in connection to the standard BLE Heart Rate service of Nilox ONAIR.
/// Uses Core Bluetooth restoration and bluetooth-central background mode.
/// iOS can still interrupt delivery; intervals with no reading remain empty.
final class HeartRateMonitor: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    enum Connection: Equatable {
        case disabled, bluetoothOff, permissionDenied, searching, connecting, listening, notFound, interrupted, failed
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
            }
        }
    }

    @Published private(set) var enabled: Bool
    @Published private(set) var connection: Connection = .disabled
    @Published private(set) var latestBPM: Int?
    @Published private(set) var latestReadingAt: Date?
    @Published private(set) var buckets: [HeartRateBucket] = []
    @Published private(set) var storageError: String?

    private static let enabledKey = "gymapp.heart.enabled.v1"
    private static let peripheralKey = "gymapp.heart.peripheralUUID.v1"
    private static let restorationID = "com.gymtrackerpro.onair.central.v1"
    private static let serviceID = CBUUID(string: "180D")
    private static let measurementID = CBUUID(string: "2A37")

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
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
        connection = .disabled
        saveHistory()
    }

    /// Re-attempt discovery if an old Core Bluetooth device identifier is no longer valid.
    func searchAgain() {
        guard enabled else { return }
        stopScanning()
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        UserDefaults.standard.removeObject(forKey: Self.peripheralKey)
        connectIfPossible()
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
        peripheral = device
        device.delegate = self
        UserDefaults.standard.set(device.identifier.uuidString, forKey: Self.peripheralKey)
    }

    private func startScanning() {
        guard enabled, central.state == .poweredOn else { return }
        stopScanning()
        connection = .searching
        scanSequence += 1
        let thisScan = scanSequence
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
        let knownUUID = UserDefaults.standard.string(forKey: Self.peripheralKey)
        guard advertisedName.uppercased() == "ONAIR" || device.identifier.uuidString == knownUUID else { return }
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
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.serviceID }) else {
            connection = .failed
            return
        }
        peripheral.discoverCharacteristics([Self.measurementID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard enabled else { return }
        guard error == nil,
              let char = service.characteristics?.first(where: { $0.uuid == Self.measurementID }),
              char.properties.contains(.notify) else {
            connection = .failed
            return
        }
        peripheral.setNotifyValue(true, for: char)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard enabled, characteristic.uuid == Self.measurementID else { return }
        connection = error == nil && characteristic.isNotifying ? .listening : .failed
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
        let previousSlot = buckets.last?.slotStart
        HeartRateHistory.record(bpm: bpm, at: now, in: &buckets)
        // Save first reading of each interval immediately, then at most every 30s.
        if previousSlot != HeartRateHistory.slot(for: now) || now.timeIntervalSince(lastDiskWrite) >= 30 {
            saveHistory()
        }
    }
}
