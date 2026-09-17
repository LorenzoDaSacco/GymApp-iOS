import SwiftUI
import WebKit

struct MuscleMapView: UIViewRepresentable {
    let target: MuscleTarget

    final class Coordinator {
        var loadedTarget: MuscleTarget?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: configuration)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.isUserInteractionEnabled = false
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard context.coordinator.loadedTarget != target else { return }
        context.coordinator.loadedTarget = target

        guard let url = Bundle.main.url(forResource: "mappa", withExtension: "svg"),
              var svg = try? String(contentsOf: url, encoding: .utf8) else { return }

        svg = svg.replacingOccurrences(of: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>", with: "")

        // La nuova SVG contiene fronte e retro nello stesso canvas 1312×1199.
        // Ritagliamo la zona utile in base al muscolo allenato, così la figura
        // rimane centrata e non viene mostrata minuscola nel riquadro.
        let viewBox: String
        switch target {
        case .chest: viewBox = "120 145 380 235"
        case .shoulders: viewBox = "115 175 390 180"
        case .biceps: viewBox = "125 260 390 190"
        case .quads: viewBox = "170 540 300 330"
        case .back: viewBox = "750 145 480 410"
        case .triceps: viewBox = "755 255 475 205"
        case .hamstrings: viewBox = "810 610 330 250"
        case .fullBody: viewBox = "90 130 1140 1030"
        }

        // ID reali presenti nella nuova SVG. Il fronte viene usato per petto,
        // spalle, bicipiti e quadricipiti; il retro per dorso, tricipiti,
        // femorali/glutei e polpacci.
        let highlighted: [String]
        switch target {
        case .chest:
            highlighted = ["front_pectoralis_left", "front_pectoralis_right"]
        case .shoulders:
            highlighted = ["front_deltoid_left", "front_deltoid_right", "back_rear_deltoid_left", "back_rear_deltoid_right"]
        case .biceps:
            highlighted = ["front_biceps_left", "front_biceps_right"]
        case .quads:
            highlighted = ["front_quad_left", "front_quad_right"]
        case .back:
            highlighted = ["back_lats_left", "back_lats_right", "back_trapezius", "back_erectors_left", "back_erectors_right"]
        case .triceps:
            highlighted = ["back_triceps_left", "back_triceps_right"]
        case .hamstrings:
            highlighted = ["back_hamstring_left", "back_hamstring_right", "back_glute_left", "back_glute_right"]
        case .fullBody:
            highlighted = []
        }

        let ids = highlighted.map { "'\($0)'" }.joined(separator: ",")
        let replacement = """
        <svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%" viewBox="\(viewBox)" preserveAspectRatio="xMidYMid meet">
        """
        if let start = svg.range(of: #"<svg[^>]*>"#, options: .regularExpression) {
            svg.replaceSubrange(start, with: replacement)
        }

        let html = """
        <html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
        <style>
        html,body{margin:0;padding:0;width:100%;height:100%;background:transparent;overflow:hidden}
        svg{width:100%;height:100%;display:block}
        .muscle{transition:none!important}
        .muscle.active{fill:#ff0000!important;fill-opacity:.86!important;stroke:#ff0000!important;stroke-width:2!important}
        .muscle.dimmed{fill-opacity:.06!important}
        </style></head><body>
        \(svg)
        <script>
        const highlighted=[\(ids)];
        document.querySelectorAll('.muscle').forEach(el=>{
            el.classList.remove('active','dimmed');
            if (highlighted.length && highlighted.includes(el.id)) el.classList.add('active');
            else if (highlighted.length) el.classList.add('dimmed');
        });
        </script>
        </body></html>
        """
        web.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
    }
}
