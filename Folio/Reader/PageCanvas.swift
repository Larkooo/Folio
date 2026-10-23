import SwiftUI
import UIKit

/// Draws one page's glyphs straight from its chapter's layout manager.
struct PageCanvas: UIViewRepresentable {
    let page: BookLayout.Page

    func makeUIView(context: Context) -> PageCanvasView {
        PageCanvasView()
    }

    func updateUIView(_ view: PageCanvasView, context: Context) {
        view.page = page
    }
}

final class PageCanvasView: UIView {
    var page: BookLayout.Page? {
        didSet {
            if page != oldValue { setNeedsDisplay() }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ rect: CGRect) {
        guard let page else { return }
        page.layoutManager.drawBackground(forGlyphRange: page.glyphRange, at: .zero)
        page.layoutManager.drawGlyphs(forGlyphRange: page.glyphRange, at: .zero)
    }
}
