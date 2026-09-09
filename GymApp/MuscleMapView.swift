
import SwiftUI
import WebKit

struct MuscleMapView: UIViewRepresentable {
    let target: MuscleTarget
    func makeUIView(context: Context) -> WKWebView {
        let v = WKWebView(); v.isOpaque = false; v.backgroundColor = .clear
        v.scrollView.isScrollEnabled=false; v.scrollView.bounces=false
        return v
    }
    func updateUIView(_ web: WKWebView, context: Context) {
        guard let url=Bundle.main.url(forResource:"mappa",withExtension:"svg"),
              var svg=try? String(contentsOf:url,encoding:.utf8) else { return }
        svg=svg.replacingOccurrences(of:"<?xml version=\"1.0\" encoding=\"UTF-8\"?>",with:"")
        let t=target.rawValue
        let html="""
        <html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;background:transparent;overflow:hidden}svg{width:100%;height:auto;display:block}
        .a{opacity:1!important;filter:drop-shadow(0 0 4px #ff3347)} .d{opacity:.16!important}</style></head>
        <body>\(svg)<script>
        const t="\(t)";
        const m={chest:[1,2],biceps:[3,4],quads:[11,12],back:[17,18],triceps:[19,20],hamstrings:[24,25,26,27],shoulders:[32,33,34,35]};
        document.querySelectorAll('[id^="muscle-"]').forEach(e=>{let n=parseInt(e.id.replace('muscle-','')); if(t!='fullBody'){e.classList.add((m[t]||[]).includes(n)?'a':'d')}})
        </script></body></html>
        """
        web.loadHTMLString(html,baseURL:Bundle.main.bundleURL)
    }
}
