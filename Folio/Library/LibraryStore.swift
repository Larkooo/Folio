import Foundation
import Observation
import UIKit

struct ReadingPosition: Codable, Hashable, Sendable {
    var chapter: Int = 0
    var offset: Int = 0
}

struct BookRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var author: String
    var folderName: String
    var hasCover: Bool
    var addedAt: Date
    var lastOpenedAt: Date?
    var position = ReadingPosition()
    var progress: Double = 0
}

/// The books on this device. Each book lives in its own folder under Application Support/Library,
/// with the original EPUB and an extracted cover image; `library.json` indexes them.
@MainActor
@Observable
final class LibraryStore {
    private(set) var books: [BookRecord] = []
    private(set) var isImporting = false
    var message: String?

    @ObservationIgnored private var coverCache: [UUID: UIImage] = [:]
    @ObservationIgnored private var isPrepared = false

    nonisolated static let rootURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Library", directoryHint: .isDirectory)
    }()

    private static var indexURL: URL { rootURL.appending(path: "library.json") }
    private static let seededKey = "library.seededSample"

    init() {
        loadIndex()
    }

    var recentBook: BookRecord? {
        let opened = books.filter { $0.lastOpenedAt != nil }
        return opened.max { ($0.lastOpenedAt ?? .distantPast) < ($1.lastOpenedAt ?? .distantPast) } ?? books.first
    }

    func book(with id: UUID) -> BookRecord? {
        books.first { $0.id == id }
    }

    func epubURL(for book: BookRecord) -> URL {
        Self.folderURL(book.folderName).appending(path: "book.epub")
    }

    func cover(for book: BookRecord) -> UIImage? {
        guard book.hasCover else { return nil }
        if let cached = coverCache[book.id] { return cached }
        let url = Self.folderURL(book.folderName).appending(path: "cover")
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        let thumbnail = image.preparingThumbnail(of: CGSize(width: 600, height: 900)) ?? image
        coverCache[book.id] = thumbnail
        return thumbnail
    }

    /// Adds the bundled sample book the first time the app runs.
    func prepare() async {
        guard !isPrepared else { return }
        isPrepared = true
        guard !UserDefaults.standard.bool(forKey: Self.seededKey),
              let url = Bundle.main.url(forResource: "harbour-light", withExtension: "epub")
        else { return }
        await importBooks(from: [url])
        UserDefaults.standard.set(true, forKey: Self.seededKey)
    }

    func importBooks(from urls: [URL]) async {
        isImporting = true
        defer { isImporting = false }

        for url in urls {
            do {
                let record = try await Task.detached(priority: .userInitiated) {
                    try Self.ingest(url)
                }.value
                if let existing = books.first(where: { $0.title == record.title && $0.author == record.author }) {
                    try? FileManager.default.removeItem(at: Self.folderURL(record.folderName))
                    message = "“\(existing.title)” is already in your library."
                    continue
                }
                books.insert(record, at: 0)
                saveIndex()
            } catch {
                message = "Folio could not open “\(url.deletingPathExtension().lastPathComponent)”. \(error.localizedDescription)"
            }
        }
    }

    func remove(_ book: BookRecord) {
        try? FileManager.default.removeItem(at: Self.folderURL(book.folderName))
        coverCache[book.id] = nil
        books.removeAll { $0.id == book.id }
        saveIndex()
    }

    func markOpened(_ id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].lastOpenedAt = .now
        saveIndex()
    }

    func updateReading(_ id: UUID, position: ReadingPosition, progress: Double) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        guard books[index].position != position else { return }
        books[index].position = position
        books[index].progress = progress
        books[index].lastOpenedAt = .now
        saveIndex()
    }

    // MARK: - Storage

    private nonisolated static func folderURL(_ name: String) -> URL {
        rootURL.appending(path: name, directoryHint: .isDirectory)
    }

    private nonisolated static func ingest(_ url: URL) throws -> BookRecord {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let metadata = try EPUBPackage(data: data).metadata()

        let id = UUID()
        let folder = folderURL(id.uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appending(path: "book.epub"), options: .atomic)
        var hasCover = false
        if let cover = metadata.cover, UIImage(data: cover) != nil {
            try cover.write(to: folder.appending(path: "cover"), options: .atomic)
            hasCover = true
        }

        return BookRecord(
            id: id,
            title: metadata.title,
            author: metadata.author,
            folderName: id.uuidString,
            hasCover: hasCover,
            addedAt: .now
        )
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: Self.indexURL),
              let decoded = try? JSONDecoder().decode([BookRecord].self, from: data)
        else { return }
        books = decoded
    }

    private func saveIndex() {
        do {
            try FileManager.default.createDirectory(at: Self.rootURL, withIntermediateDirectories: true)
            try JSONEncoder().encode(books).write(to: Self.indexURL, options: .atomic)
        } catch {
            message = "Folio could not save your library."
        }
    }
}
