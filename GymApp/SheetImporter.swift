import SwiftUI
import Vision
import VisionKit
import PhotosUI
import PDFKit
import UIKit

struct ImportedExercise: Identifiable, Equatable {
    let id = UUID()
    var day: String
    var name: String
    var reps: String
    var sets: Int
    var recovery: String
}

@MainActor
final class SheetImporter: ObservableObject {
    @Published var isBusy = false
    @Published var recognizedText = ""
    @Published var items: [ImportedExercise] = []
    @Published var errorMessage: String?

    func analyze(image: UIImage) {
        isBusy = true; errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let text = Self.ocr(image: image)
            let parsed = Self.parse(text: text)
            DispatchQueue.main.async { self.recognizedText = text; self.items = parsed; self.isBusy = false }
        }
    }

    func analyze(pdfURL: URL) {
        isBusy = true; errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            var allText = ""
            if let doc = PDFDocument(url: pdfURL) {
                for i in 0..<doc.pageCount {
                    guard let page = doc.page(at: i) else { continue }
                    let bounds = page.bounds(for: .mediaBox)
                    let scale: CGFloat = 2
                    let renderer = UIGraphicsImageRenderer(size: CGSize(width: bounds.width * scale, height: bounds.height * scale))
                    let image = renderer.image { ctx in
                        UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: ctx.format.bounds.size))
                        ctx.cgContext.saveGState(); ctx.cgContext.translateBy(x: 0, y: ctx.format.bounds.height); ctx.cgContext.scaleBy(x: scale, y: -scale); page.draw(with: .mediaBox, to: ctx.cgContext); ctx.cgContext.restoreGState()
                    }
                    allText += Self.ocr(image: image) + "\n"
                }
            }
            let parsed = Self.parse(text: allText)
            DispatchQueue.main.async { self.recognizedText = allText; self.items = parsed; self.isBusy = false }
        }
    }

    nonisolated static func ocr(image: UIImage) -> String {
        guard let cgImage = image.cgImage else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["it-IT", "en-US"]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try handler.perform([request]) } catch { return "" }
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    nonisolated static func parse(text: String) -> [ImportedExercise] {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var day = "LUNEDÌ"; var result: [ImportedExercise] = []
        let dayMap: [String:String] = ["LUNEDI":"LUNEDÌ","LUNEDÌ":"LUNEDÌ","MARTEDI":"MARTEDÌ","MARTEDÌ":"MARTEDÌ","MERCOLEDI":"MERCOLEDÌ","MERCOLEDÌ":"MERCOLEDÌ","GIOVEDI":"GIOVEDÌ","GIOVEDÌ":"GIOVEDÌ","VENERDI":"VENERDÌ","VENERDÌ":"VENERDÌ","SABATO":"SABATO","DOMENICA":"DOMENICA","GIORNO 1":"LUNEDÌ","GIORNO 2":"MARTEDÌ","GIORNO 3":"MERCOLEDÌ"]
        for line in lines {
            let upper = line.uppercased().replacingOccurrences(of: "  ", with: " ")
            for (k,v) in dayMap where upper.contains(k) && (upper.count < 28 || upper.hasPrefix("GIORNO")) { day = v; break }
            guard let match = try? NSRegularExpression(pattern: #"(\d+)\s*[xX×]\s*(\d+(?:[-–]\d+)?|RM)"#).firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { continue }
            guard let setsRange = Range(match.range(at: 1), in: line), let repsRange = Range(match.range(at: 2), in: line) else { continue }
            let sets = Int(line[setsRange]) ?? 3; let reps = String(line[repsRange])
            let before = String(line[..<(line.range(of: String(line[setsRange]))?.lowerBound ?? line.startIndex)]).trimmingCharacters(in: .whitespacesAndNewlines)
            let name = before.replacingOccurrences(of: "—", with: " ").replacingOccurrences(of: "-", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.count >= 3 else { continue }
            var recovery = ""
            if let rec = line.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) { recovery = String(line[rec]) }
            result.append(ImportedExercise(day: day, name: name, reps: reps, sets: sets, recovery: recovery))
        }
        return result
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController { let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker; init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) { if let image = info[.originalImage] as? UIImage { parent.onImage(image) }; picker.dismiss(animated: true) }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}
