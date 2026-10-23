import Foundation

struct EPUBMetadata: Sendable {
    var title: String
    var author: String
    var cover: Data?
}

struct TOCEntry: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let chapter: Int
    let depth: Int
}

/// A parsed book, ready for typesetting. Chapter text is semantic (see `ChapterRenderer`).
final class LoadedBook: @unchecked Sendable {
    struct Chapter {
        let title: String?
        let text: NSAttributedString
    }

    let title: String
    let author: String
    let chapters: [Chapter]
    let contents: [TOCEntry]
    private let chapterStarts: [Int]
    private let totalLength: Int

    init(title: String, author: String, chapters: [Chapter], contents: [TOCEntry]) {
        self.title = title
        self.author = author
        self.chapters = chapters
        self.contents = contents
        var starts: [Int] = []
        var running = 0
        for chapter in chapters {
            starts.append(running)
            running += chapter.text.length
        }
        chapterStarts = starts
        totalLength = max(running, 1)
    }

    func progress(at position: ReadingPosition) -> Double {
        guard chapters.indices.contains(position.chapter) else { return 0 }
        let offset = chapterStarts[position.chapter] + min(position.offset, chapters[position.chapter].text.length)
        return min(max(Double(offset) / Double(totalLength), 0), 1)
    }

    func title(forChapter index: Int) -> String? {
        guard chapters.indices.contains(index) else { return nil }
        return contents.last { $0.chapter <= index && $0.depth == 0 }?.title ?? chapters[index].title
    }
}

enum EPUBError: LocalizedError {
    case notAnEPUB
    case missingPackage
    case noReadableText

    var errorDescription: String? {
        switch self {
        case .notAnEPUB: "This file is not an EPUB book."
        case .missingPackage: "This EPUB is missing its package file."
        case .noReadableText: "This EPUB does not contain any readable text."
        }
    }
}

struct EPUBPackage {
    struct Item: Hashable {
        let id: String
        let path: String
        let mediaType: String
        let properties: Set<String>

        var isDocument: Bool {
            mediaType.contains("html") || path.hasSuffix(".xhtml") || path.hasSuffix(".html") || path.hasSuffix(".htm")
        }
    }

    let archive: ZipArchive
    let title: String
    let author: String
    let spine: [Item]
    private let navItem: Item?
    private let ncxItem: Item?
    private let coverItem: Item?

    init(data: Data) throws {
        guard let archive = try? ZipArchive(data: data) else { throw EPUBError.notAnEPUB }
        self.archive = archive

        guard let containerData = try? archive.data(for: "META-INF/container.xml"),
              let container = Markup.parse(containerData).root,
              let rootPath = container.firstDescendant(named: "rootfile")?.attribute("full-path")
        else { throw EPUBError.notAnEPUB }

        let opfPath = rootPath.removingPercentEncoding ?? rootPath
        guard let opfData = try? archive.data(for: opfPath),
              let package = Markup.parse(opfData).root
        else { throw EPUBError.missingPackage }
        let base = (opfPath as NSString).deletingLastPathComponent

        let metadata = package.firstDescendant(named: "metadata")
        let title = metadata?.firstDescendant(named: "title")?.text.collapsingWhitespace ?? ""
        self.title = title.isEmpty ? "Untitled" : title
        let creatorNodes = metadata?.descendants(named: "creator") ?? []
        let creators = creatorNodes.map { $0.text.collapsingWhitespace }.filter { !$0.isEmpty }
        author = creators.isEmpty ? "Unknown author" : creators.prefix(2).joined(separator: ", ")

        var items: [String: Item] = [:]
        for node in package.firstDescendant(named: "manifest")?.elements ?? [] where node.name == "item" {
            guard let id = node.attribute("id"), let href = node.attribute("href") else { continue }
            items[id] = Item(
                id: id,
                path: Self.resolve(href, relativeTo: base),
                mediaType: node.attribute("media-type") ?? "",
                properties: Set((node.attribute("properties") ?? "").split(separator: " ").map(String.init))
            )
        }

        let spineNode = package.firstDescendant(named: "spine")
        spine = (spineNode?.elements ?? [])
            .filter { $0.name == "itemref" && $0.attribute("linear") != "no" }
            .compactMap { $0.attribute("idref").flatMap { items[$0] } }

        navItem = items.values.first { $0.properties.contains("nav") }
        ncxItem = spineNode?.attribute("toc").flatMap { items[$0] }
            ?? items.values.first { $0.mediaType == "application/x-dtbncx+xml" }

        coverItem = Self.findCover(in: items, metadata: metadata)
    }

    private static func findCover(in items: [String: Item], metadata: MarkupNode?) -> Item? {
        if let declared = items.values.first(where: { $0.properties.contains("cover-image") }) {
            return declared
        }
        let metaNode = metadata?.descendants(named: "meta").first { $0.attribute("name") == "cover" }
        if let id = metaNode?.attribute("content"), let item = items[id], item.mediaType.hasPrefix("image/") {
            return item
        }
        return items.values.first { item in
            item.mediaType.hasPrefix("image/") && item.id.lowercased().contains("cover")
        }
    }

    func metadata() -> EPUBMetadata {
        EPUBMetadata(title: title, author: author, cover: coverItem.flatMap { try? archive.data(for: $0.path) })
    }

    func loadBook() throws -> LoadedBook {
        var chapters: [LoadedBook.Chapter] = []
        var chapterForPath: [String: Int] = [:]

        for item in spine where item.isDocument && item != navItem {
            guard let data = try? archive.data(for: item.path) else { continue }
            let rendered = ChapterRenderer.render(data)
            let hasText = rendered.text.string.contains { !$0.isWhitespace && $0 != "\u{2042}" }
            guard hasText else { continue }
            chapterForPath[item.path] = chapters.count
            chapters.append(LoadedBook.Chapter(title: rendered.heading, text: rendered.text))
        }
        guard !chapters.isEmpty else { throw EPUBError.noReadableText }

        var contents: [TOCEntry] = []
        var seen = Set<String>()
        for entry in tableOfContents() {
            guard let chapter = chapterForPath[entry.path], !entry.title.isEmpty else { continue }
            let key = "\(chapter)|\(entry.title)"
            guard seen.insert(key).inserted else { continue }
            contents.append(TOCEntry(id: contents.count, title: entry.title, chapter: chapter, depth: entry.depth))
        }
        if contents.isEmpty {
            for (index, chapter) in chapters.enumerated() {
                contents.append(TOCEntry(id: index, title: chapter.title ?? "Section \(index + 1)", chapter: index, depth: 0))
            }
        }
        return LoadedBook(title: title, author: author, chapters: chapters, contents: contents)
    }

    // MARK: - Table of contents

    private struct RawEntry {
        let title: String
        let path: String
        let depth: Int
    }

    private func tableOfContents() -> [RawEntry] {
        var entries: [RawEntry] = []
        if let navItem, let data = try? archive.data(for: navItem.path), let root = Markup.parse(data).root {
            let base = (navItem.path as NSString).deletingLastPathComponent
            let navs = root.descendants(named: "nav")
            let toc = navs.first { ($0.attribute("epub:type") ?? $0.attribute("type") ?? "").contains("toc") } ?? navs.first
            if let list = toc?.firstDescendant(named: "ol") ?? toc?.firstDescendant(named: "ul") {
                walkNavList(list, depth: 0, base: base, into: &entries)
            }
        }
        if entries.isEmpty, let ncxItem, let data = try? archive.data(for: ncxItem.path),
           let navMap = Markup.parse(data).root?.firstDescendant(named: "navmap") {
            let base = (ncxItem.path as NSString).deletingLastPathComponent
            walkNavPoints(navMap, depth: 0, base: base, into: &entries)
        }
        return entries
    }

    private func walkNavList(_ list: MarkupNode, depth: Int, base: String, into entries: inout [RawEntry]) {
        for item in list.elements where item.name == "li" {
            if let link = item.child(named: "a"), let href = link.attribute("href") {
                entries.append(RawEntry(title: link.text.collapsingWhitespace, path: Self.resolve(href, relativeTo: base), depth: depth))
            }
            if let sublist = item.child(named: "ol") ?? item.child(named: "ul") {
                walkNavList(sublist, depth: depth + 1, base: base, into: &entries)
            }
        }
    }

    private func walkNavPoints(_ node: MarkupNode, depth: Int, base: String, into entries: inout [RawEntry]) {
        for point in node.elements where point.name == "navpoint" {
            let title = point.child(named: "navlabel")?.firstDescendant(named: "text")?.text.collapsingWhitespace ?? ""
            if let src = point.child(named: "content")?.attribute("src") {
                entries.append(RawEntry(title: title, path: Self.resolve(src, relativeTo: base), depth: depth))
            }
            walkNavPoints(point, depth: depth + 1, base: base, into: &entries)
        }
    }

    // MARK: - Paths

    /// Resolves a manifest or TOC href against the directory of the file that references it.
    static func resolve(_ href: String, relativeTo base: String) -> String {
        var href = href
        if let hash = href.firstIndex(of: "#") { href = String(href[..<hash]) }
        href = href.removingPercentEncoding ?? href
        let combined = base.isEmpty || href.hasPrefix("/") ? href : base + "/" + href
        var parts: [Substring] = []
        for part in combined.split(separator: "/") {
            switch part {
            case ".": continue
            case "..": _ = parts.popLast()
            default: parts.append(part)
            }
        }
        return parts.joined(separator: "/")
    }
}

extension String {
    var collapsingWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
