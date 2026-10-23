import UIKit

struct LayoutKey: Hashable, Sendable {
    var textWidth: Int
    var textHeight: Int
    var style: TypeStyle

    var textSize: CGSize {
        CGSize(width: textWidth, height: textHeight)
    }
}

/// A whole book broken into pages of one size. Each page is a TextKit container that shares its
/// chapter's layout manager, so a page draws exactly the glyphs pagination measured.
final class BookLayout: @unchecked Sendable {
    struct Page: Equatable {
        let chapter: Int
        let characterRange: NSRange
        let glyphRange: NSRange
        let layoutManager: NSLayoutManager

        static func == (lhs: Page, rhs: Page) -> Bool {
            lhs.layoutManager === rhs.layoutManager && lhs.glyphRange == rhs.glyphRange
        }
    }

    let key: LayoutKey
    let pages: [Page]
    let chapterFirstPage: [Int]
    private let storages: [NSTextStorage]

    init(key: LayoutKey, pages: [Page], chapterFirstPage: [Int], storages: [NSTextStorage]) {
        self.key = key
        self.pages = pages
        self.chapterFirstPage = chapterFirstPage
        self.storages = storages
    }

    func pageIndex(for position: ReadingPosition) -> Int {
        guard !pages.isEmpty, chapterFirstPage.indices.contains(position.chapter) else { return 0 }
        let first = chapterFirstPage[position.chapter]
        let last = position.chapter + 1 < chapterFirstPage.count ? chapterFirstPage[position.chapter + 1] - 1 : pages.count - 1
        guard first <= last else { return min(first, pages.count - 1) }
        for index in first...last where NSMaxRange(pages[index].characterRange) > position.offset {
            // Page sizes differ between layouts, so the old page's first line can land near the bottom of a
            // new page. The reader was looking at what follows it, so show the next page instead.
            let range = pages[index].characterRange
            let consumed = Double(position.offset - range.location) / Double(max(range.length, 1))
            return consumed > 0.8 && index < last ? index + 1 : index
        }
        return last
    }

    func position(atPage index: Int) -> ReadingPosition {
        guard pages.indices.contains(index) else { return ReadingPosition() }
        let page = pages[index]
        return ReadingPosition(chapter: page.chapter, offset: page.characterRange.location)
    }

    func pagesLeftInChapter(from index: Int) -> Int {
        guard pages.indices.contains(index) else { return 0 }
        let chapter = pages[index].chapter
        let next = chapter + 1 < chapterFirstPage.count ? chapterFirstPage[chapter + 1] : pages.count
        return max(next - index - 1, 0)
    }

    func isChapterOpening(_ index: Int) -> Bool {
        guard pages.indices.contains(index) else { return false }
        return chapterFirstPage[pages[index].chapter] == index
    }
}

enum Paginator {
    /// Runs off the main thread. TextKit 1 objects are safe to build on a background thread as long as
    /// only one thread touches them at a time, and the layout is handed over only once complete.
    static func paginate(_ book: LoadedBook, key: LayoutKey) -> BookLayout {
        var pages: [BookLayout.Page] = []
        var chapterFirstPage: [Int] = []
        var storages: [NSTextStorage] = []
        let size = key.textSize

        for (chapterIndex, chapter) in book.chapters.enumerated() {
            chapterFirstPage.append(pages.count)
            let styled = Typesetter.style(chapter.text, with: key.style, pageHeight: size.height)
            let storage = NSTextStorage(attributedString: styled)
            let layoutManager = NSLayoutManager()
            layoutManager.usesFontLeading = true
            storage.addLayoutManager(layoutManager)
            storages.append(storage)

            let glyphCount = layoutManager.numberOfGlyphs
            var pageCount = 0
            repeat {
                let container = NSTextContainer(size: size)
                container.lineFragmentPadding = 0
                layoutManager.addTextContainer(container)
                let glyphRange = layoutManager.glyphRange(for: container)
                let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                pages.append(BookLayout.Page(
                    chapter: chapterIndex,
                    characterRange: characterRange,
                    glyphRange: glyphRange,
                    layoutManager: layoutManager
                ))
                pageCount += 1
                // An empty container means nothing more fits (or nothing is left); stop either way.
                if glyphRange.length == 0 || NSMaxRange(glyphRange) >= glyphCount { break }
            } while pageCount < 10_000
        }

        return BookLayout(key: key, pages: pages, chapterFirstPage: chapterFirstPage, storages: storages)
    }
}
