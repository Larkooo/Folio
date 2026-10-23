import Foundation
import Observation

@MainActor
@Observable
final class ReaderModel {
    private(set) var book: LoadedBook?
    private(set) var layout: BookLayout?
    private(set) var failure: String?
    private(set) var page = 0
    /// Where the reader is, independent of page size. Pages are recomputed from this after every relayout,
    /// which is what keeps the same text in view when the device folds or unfolds.
    private(set) var position: ReadingPosition

    @ObservationIgnored private var loadTask: Task<LoadedBook, Error>?
    #if DEBUG
    @ObservationIgnored private var appliedDebugPage = false
    #endif

    init(position: ReadingPosition) {
        self.position = position
    }

    var pageCount: Int { layout?.pages.count ?? 0 }

    var progress: Double {
        book?.progress(at: position) ?? 0
    }

    func prepare(url: URL, key: LayoutKey) async {
        do {
            let book = try await loadBook(url: url)
            guard layout?.key != key else { return }
            if layout != nil {
                // Coalesce bursts of geometry changes (rotation, folding) into one relayout.
                try await Task.sleep(for: .milliseconds(60))
            }
            let layout = await Task.detached(priority: .userInitiated) {
                Paginator.paginate(book, key: key)
            }.value
            try Task.checkCancellation()
            self.layout = layout
            page = layout.pageIndex(for: position)
            #if DEBUG
            if let debugPage = DebugFlags.page, !appliedDebugPage {
                appliedDebugPage = true
                show(page: debugPage)
            }
            #endif
        } catch is CancellationError {
            return
        } catch {
            failure = error.localizedDescription
        }
    }

    func show(page newPage: Int) {
        guard let layout, !layout.pages.isEmpty else { return }
        page = min(max(newPage, 0), layout.pages.count - 1)
        position = layout.position(atPage: page)
    }

    func show(chapter: Int) {
        guard let layout, layout.chapterFirstPage.indices.contains(chapter) else { return }
        show(page: layout.chapterFirstPage[chapter])
    }

    private func loadBook(url: URL) async throws -> LoadedBook {
        if let book { return book }
        let task = loadTask ?? Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            return try EPUBPackage(data: data).loadBook()
        }
        loadTask = task
        let book = try await task.value
        self.book = book
        return book
    }
}
