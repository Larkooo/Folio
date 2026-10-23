import SwiftUI

enum PageSide {
    case left, right, single
}

/// Page metrics shared by both layouts. Spread pages and the closed single page come out nearly the same
/// size on the Duo, so text reflows very little when it folds.
struct PageMetrics {
    let fold: FoldLayout

    var isSpread: Bool { fold.isSpread }

    private var pageWidth: CGFloat {
        isSpread ? min(fold.leftPage.width, fold.rightPage.width) : fold.size.width
    }

    /// Pages run under the safe area (the paper fills the screen), so margins only grow where an inset is
    /// larger than the margin itself. The running head then sits beside the camera rather than below it.
    func margins(for side: PageSide) -> EdgeInsets {
        let safe = fold.safeArea
        let outer = max(24, (pageWidth * 0.075).rounded())
        let inner = max(20, (pageWidth * 0.06).rounded())
        let top = max(46, safe.top)
        let bottom = max(42, safe.bottom + 14)
        let leadingOuter = max(outer, safe.leading + 12)
        let trailingOuter = max(outer, safe.trailing + 12)
        switch side {
        case .left: return EdgeInsets(top: top, leading: leadingOuter, bottom: bottom, trailing: inner)
        case .right: return EdgeInsets(top: top, leading: inner, bottom: bottom, trailing: trailingOuter)
        case .single: return EdgeInsets(top: top, leading: leadingOuter, bottom: bottom, trailing: trailingOuter)
        }
    }

    /// One size for every page, so both sides of a spread share a layout.
    var textSize: CGSize {
        let sides: [(PageSide, CGFloat)] = isSpread
            ? [(.left, fold.leftPage.width), (.right, fold.rightPage.width)]
            : [(.single, fold.size.width)]
        let width = sides.map { side, pageWidth in
            let margins = margins(for: side)
            return pageWidth - margins.leading - margins.trailing
        }.min() ?? 0
        let margins = margins(for: sides[0].0)
        return CGSize(width: floor(width), height: floor(fold.size.height - margins.top - margins.bottom))
    }

    func layoutKey(for style: TypeStyle) -> LayoutKey {
        LayoutKey(textWidth: Int(textSize.width), textHeight: Int(textSize.height), style: style)
    }
}

struct PageView: View {
    let layout: BookLayout
    let book: LoadedBook
    let index: Int
    let side: PageSide
    let metrics: PageMetrics
    let theme: ReaderTheme

    var body: some View {
        let margins = metrics.margins(for: side)
        VStack(spacing: 0) {
            // Color.clear keeps the margin when there is no running head (chapter openings), so facing
            // pages stay aligned.
            Color.clear
                .frame(height: margins.top)
                .overlay { runningHead.padding(.top, 8) }

            Group {
                if layout.pages.indices.contains(index) {
                    PageCanvas(page: layout.pages[index])
                } else {
                    Color.clear
                }
            }
            .frame(width: metrics.textSize.width, height: metrics.textSize.height, alignment: .topLeading)
            .frame(maxWidth: .infinity)

            Color.clear
                .frame(height: margins.bottom)
                .overlay(alignment: folioAlignment) { folio.padding(.bottom, 8) }
        }
        .padding(.leading, margins.leading)
        .padding(.trailing, margins.trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var runningHead: some View {
        if layout.pages.indices.contains(index), !layout.isChapterOpening(index) {
            let chapter = layout.pages[index].chapter
            let text = side == .left ? book.title : (book.title(forChapter: chapter) ?? book.title)
            Text(text)
                .font(.system(size: 12, design: .serif).smallCaps())
                .foregroundStyle(theme.secondaryInk)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var folio: some View {
        if layout.pages.indices.contains(index) {
            Text("\(index + 1)")
                .font(.system(size: 12, design: .serif).monospacedDigit())
                .foregroundStyle(theme.secondaryInk)
        }
    }

    private var folioAlignment: Alignment {
        switch side {
        case .left: .leading
        case .right: .trailing
        case .single: .center
        }
    }
}

/// Two facing pages either side of the fold.
struct SpreadView: View {
    let layout: BookLayout
    let book: LoadedBook
    let leftIndex: Int
    let metrics: PageMetrics
    let theme: ReaderTheme

    var body: some View {
        let fold = metrics.fold
        ZStack(alignment: .topLeading) {
            PageView(layout: layout, book: book, index: leftIndex, side: .left, metrics: metrics, theme: theme)
                .frame(width: fold.leftPage.width, height: fold.size.height)

            PageView(layout: layout, book: book, index: leftIndex + 1, side: .right, metrics: metrics, theme: theme)
                .frame(width: fold.rightPage.width, height: fold.size.height)
                .offset(x: fold.rightPage.minX)
        }
        .frame(width: fold.size.width, height: fold.size.height, alignment: .topLeading)
    }
}

/// The shadow of a book's binding, drawn over the fold. It stays put while pages slide past, like the
/// crease it sits on, and deepens as the Duo folds towards a book posture.
struct GutterShade: View {
    let theme: ReaderTheme
    let openness: Double

    var body: some View {
        let base = theme.isDark ? 0.32 : 0.075
        let depth = base * (1 + (1 - openness) * 1.8)
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0), location: 0),
                .init(color: .black.opacity(depth * 0.35), location: 0.38),
                .init(color: .black.opacity(depth), location: 0.5),
                .init(color: .black.opacity(depth * 0.3), location: 0.6),
                .init(color: .black.opacity(0), location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .animation(.smooth(duration: 0.4), value: depth)
    }
}
