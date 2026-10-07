import SwiftUI
import Charts
import Combine

struct HeartDashboardView: View {
    @EnvironmentObject private var monitor: HeartRateMonitor
    @Environment(\.gymAccentColor) private var accentColor
    @State private var selectedDate = Date()
    @State private var now = Date()

    private var selectedSummary: HeartRateDaySummary { monitor.summary(for: selectedDate) }
    private var lastValueIsFresh: Bool {
        monitor.connection == .listening &&
        (monitor.latestReadingAt.map { now.timeIntervalSince($0) < 120 } ?? false)
    }

    private var week: [HeartRateDaySummary] {
        let calendar = Calendar.autoupdatingCurrent
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now).map { monitor.summary(for: $0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                controlCard
                daySection
                weekSection
                intervalsSection
                Text("Le misurazioni dipendono dalle notifiche Bluetooth del bracciale. iOS può interromperle in background: gli intervalli senza dati rimangono vuoti. Non è un dispositivo medico.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding()
        }
        .navigationTitle("Cuore")
        .onAppear { now = Date() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { newDate in
            now = newDate
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("NILOX · HEART TRACKER")
                .font(.caption2.bold())
                .tracking(2.5)
                .foregroundStyle(accentColor)
            Text("Ogni battito conta.")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
            Text("Riepilogo reale, senza dover avviare un allenamento.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("FREQUENZA CARDIACA", systemImage: "heart.fill")
                        .font(.caption.bold())
                        .tracking(1)
                        .foregroundStyle(Color.white.opacity(0.85))
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(lastValueIsFresh ? "\(monitor.latestBPM ?? 0)" : "—")
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("BPM")
                            .font(.title3.bold())
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                    if let last = monitor.latestReadingAt {
                        Text("Ultima lettura: \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.75))
                    } else {
                        Text("Nessuna misurazione ricevuta")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                }
                Spacer()
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 38))
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.connection == .listening ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(monitor.connection.title)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                if monitor.enabled { monitor.stop() } else { monitor.start() }
            } label: {
                Label(monitor.enabled ? "Interrompi monitoraggio" : "Avvia monitoraggio", systemImage: monitor.enabled ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(monitor.enabled ? Color(red: 0.48, green: 0.22, blue: 0.30) : .white)
            .foregroundStyle(monitor.enabled ? Color.white : Color.black)

            if monitor.enabled && monitor.connection != .listening {
                Button("Cerca di nuovo il bracciale") { monitor.searchAgain() }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                if !monitor.detectedDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Dispositivi Bluetooth trovati")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.88))
                        Text("Se ONAIR non viene riconosciuto automaticamente, selezionalo qui. Il codice sotto al nome è un ID iOS, non il MAC del bracciale.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.72))
                        ForEach(Array(monitor.detectedDevices.prefix(10))) { item in
                            Button {
                                monitor.selectDevice(item.id)
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: item.advertisesHeartRate ? "heart.fill" : "antenna.radiowaves.left.and.right")
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                        Text(item.alreadyConnected ? "Già collegato a iOS · tocca per usare" :
                                             (item.advertisesHeartRate ? "Sensore cardiaco BLE" : "Dispositivo BLE"))
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.68))
                                    }
                                    Spacer(minLength: 4)
                                    if let rssi = item.rssi {
                                        Text("\(rssi) dBm")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    Image(systemName: "chevron.right").font(.caption.bold())
                                }
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if monitor.enabled && monitor.connection == .listening && !lastValueIsFresh {
                Text("Nessuna lettura recente: il Bluetooth è collegato, ma il Nilox non sta inviando battiti.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color(red: 0.60, green: 0.13, blue: 0.32), Color(red: 0.18, green: 0.12, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26)
        )
        .overlay(alignment: .topTrailing) {
            Circle().stroke(.white.opacity(0.07), lineWidth: 22)
                .frame(width: 130, height: 130).offset(x: 45, y: -50).clipped()
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Riepilogo giornaliero", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                Spacer()
            }
            DatePicker("Giorno", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
                .font(.subheadline)

            HStack(spacing: 10) {
                heartMetric("Media", selectedSummary.averageBPM.map { "\(Int($0.rounded()))" } ?? "—")
                heartMetric("Minimo", selectedSummary.minBPM.map(String.init) ?? "—")
                heartMetric("Massimo", selectedSummary.maxBPM.map(String.init) ?? "—")
            }
            Text("\(selectedSummary.intervalCount) intervalli da 10 minuti con dati")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !selectedSummary.buckets.isEmpty {
                Chart(selectedSummary.buckets) { item in
                    // Individual marks deliberately avoid connecting missing intervals.
                    PointMark(
                        x: .value("Orario", item.slotStart),
                        y: .value("BPM medi", item.averageBPM)
                    )
                    .symbolSize(30)
                    .foregroundStyle(accentColor)
                }
                .chartXAxisLabel("Orario")
                .frame(height: 180)
                .accessibilityLabel("Misurazioni cardiache disponibili del giorno")
            } else {
                Label("Nessuna misurazione in questa giornata", systemImage: "waveform.path")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 115)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    private func heartMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text("BPM").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ultimi 7 giorni").font(.headline)
            if week.contains(where: { $0.averageBPM != nil }) {
                Chart(week) { day in
                    if let avg = day.averageBPM {
                        BarMark(x: .value("Giorno", day.date, unit: .day), y: .value("Media", avg))
                            .foregroundStyle(accentColor.gradient)
                            .cornerRadius(5)
                    }
                }
                .frame(height: 155)
            } else {
                Text("Lo storico settimanale comparirà dopo le prime registrazioni.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    private var intervalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ultime letture da 10 minuti").font(.headline)
            if selectedSummary.buckets.isEmpty {
                Text("Nessun dato da mostrare.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(selectedSummary.buckets.suffix(12).reversed())) { bucket in
                    HStack {
                        Image(systemName: "heart.text.square")
                            .foregroundStyle(accentColor)
                        Text(bucket.slotStart.formatted(date: .omitted, time: .shortened))
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(bucket.averageBPM.rounded())) BPM").font(.subheadline.bold()).monospacedDigit()
                            Text("\(bucket.count) letture · \(bucket.minBPM)–\(bucket.maxBPM)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    if bucket.id != selectedSummary.buckets.first?.id { Divider().opacity(0.4) }
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}
