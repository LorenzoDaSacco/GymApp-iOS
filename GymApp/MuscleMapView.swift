import SwiftUI
import WebKit

struct MuscleMapView: UIViewRepresentable {
    let target: MuscleTarget

    func makeUIView(context: Context) -> WKWebView {
        let v = WKWebView()
        v.isOpaque = false
        v.backgroundColor = .clear
        v.scrollView.isScrollEnabled = false
        v.scrollView.bounces = false
        return v
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard let url = Bundle.main.url(forResource: "mappa", withExtension: "svg"),
              var svg = try? String(contentsOf: url, encoding: .utf8) else { return }

        svg = svg.replacingOccurrences(of: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>", with: "")

        let viewBox: String
        switch target {
        case .chest:
            viewBox = "85 75 255 185"
        case .back:
            viewBox = "445 95 210 205"
        case .shoulders:
            viewBox = "75 80 270 165"
        case .biceps:
            viewBox = "45 135 315 145"
        case .triceps:
            viewBox = "425 135 240 150"
        case .quads:
            viewBox = "120 255 180 195"
        case .hamstrings:
            viewBox = "450 255 190 205"
        case .fullBody:
            viewBox = "0 0 753 703"
        }

        let t = target.rawValue
        let highlighted: [Int] = {
            switch target {
            case .chest: return [1, 2]
            case .biceps: return [3, 4]
            case .quads: return [11, 12]
            case .back: return [17, 18]
            case .triceps: return [19, 20]
            case .hamstrings: return [24, 25, 26, 27, 28, 29, 30, 31]
            case .shoulders: return [32, 33, 34, 35]
            case .fullBody: return []
            }
        }()
        let ids = highlighted.map(String.init).joined(separator: ",")

        let replacement = """
        <svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%" viewBox="\(viewBox)" preserveAspectRatio="xMidYMid meet">
        """
        if let start = svg.range(of: #"<svg[^>]*>"#, options: .regularExpression) {
            svg.replaceSubrange(start, with: replacement)
        }

        let html = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
        <style>
        html,body{margin:0;padding:0;width:100%;height:100%;background:transparent;overflow:hidden}
        svg{width:100%;height:100%;display:block}
        .a{opacity:1!important;filter:drop-shadow(0 0 5px #ff3347)}
        .d{opacity:.14!important}
        </style>
        </head>
        <body>
        \(svg)
        <script>
        const t="\(t)";
        const highlighted=[\(ids)];
        document.querySelectorAll('[id^="muscle-"]').forEach(e=>{
            const n=parseInt(e.id.replace('muscle-',''));
            if(t!=='fullBody') e.classList.add(highlighted.includes(n)?'a':'d');
        });
        </script>
        </body>
        </html>
        """
        web.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
    }
}
