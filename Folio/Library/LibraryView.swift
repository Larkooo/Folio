import SwiftUI
import UniformTypeIdentifiers

/// Open, the library spreads across the fold: the current book on the left page, the shelf on the right.
/// Closed, it becomes a single column.
struct LibraryView: View {
    var onOpen: (BookRecord) -> Void

    @Environment(LibraryStore.self) private var library
    @Environment(ReaderSettings.self) private var settings
    @Environment(\.simulatedCreaseWidth) private var simulatedCreaseWidth

    @State private var isImporterPresented = false
    @State private var pendingRemoval: BookRecord?

    var body: some View {
        GeometryReader { proxy in
            let fold = FoldLayout(proxy: proxy, simulatedCreaseWidth: simulatedCreaseWidth)
            if fold.isSpread {
                openLayout(fold)
            } else {
                closedLayout
            }
        }
        .background(settings.theme.paper.ignoresSafeArea())
        .environment(\.colorScheme, settings.theme.colorScheme)
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.epub], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                Task { await library.importBooks(from: urls) }
            }
        }
        .confirmationDialog(
            pendingRemoval.map { "Remove “\($0.title)” from your library?" } ?? "",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { book in
            Button("Remove", role: .destructive) { library.remove(book) }
        } message: { _ in
            Text("The book and your place in it will be deleted from this device.")
        }
        .alert(
            "Import",
            isPresented: Binding(get: { library.message != nil }, set: { if !$0 { library.message = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(library.message ?? "")
        }
    }

    // MARK: - Open

    private func openLayout(_ fold: FoldLayout) -> some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let book = library.recentBook {
                    ReadingNow(book: book, cover: library.cover(for: book), style: .spread) { onOpen(book) }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 40)
            .frame(width: fold.leftPage.width, height: fold.size.height)

            VStack(alignment: .leading, spacing: 18) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                ScrollView {
                    shelf(columns: 3)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
            .frame(width: fold.rightPage.width, height: fold.size.height, alignment: .topLeading)
            .offset(x: fold.rightPage.minX)
        }
    }

    // MARK: - Closed

    private var closedLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                if let book = library.recentBook {
                    ReadingNow(book: book, cover: library.cover(for: book), style: .card) { onOpen(book) }
                } else {
                    emptyState
                }
                if library.books.count > 1 {
                    Text("All Books")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(settings.theme.ink)
                        .padding(.top, 4)
                    shelf(columns: 3, excluding: library.recentBook?.id)
                } else if library.recentBook != nil {
                    addPrompt
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .center) {
            Text("Library")
                .font(.system(size: 32, weight: .semibold, design: .serif))
            Spacer()
            if library.isImporting {
                ProgressView()
                    .padding(.trailing, 6)
            }
            GlassIconButton(systemName: "plus", label: "Add a book") {
                isImporterPresented = true
            }
        }
        .foregroundStyle(settings.theme.ink)
    }

    private func shelf(columns: Int, excluding excluded: UUID? = nil) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 18, alignment: .top), count: columns),
            alignment: .leading,
            spacing: 26
        ) {
            ForEach(library.books.filter { $0.id != excluded }) { book in
                BookTile(book: book, cover: library.cover(for: book), theme: settings.theme) {
                    onOpen(book)
                }
                .contextMenu {
                    Button("Remove from Library", systemImage: "trash", role: .destructive) {
                        pendingRemoval = book
                    }
                }
            }
            AddBookTile(theme: settings.theme) { isImporterPresented = true }
        }
    }

    private var addPrompt: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add more books")
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(settings.theme.ink)
                Text("Folio opens EPUB files from Files, AirDrop and other apps.")
                    .font(.system(size: 13))
                    .foregroundStyle(settings.theme.secondaryInk)
            }
            Spacer(minLength: 0)
            Button("Add") { isImporterPresented = true }
                .buttonStyle(.glass)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(settings.theme.secondaryInk.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your library is empty.")
                .font(.system(size: 24, design: .serif))
            Text("Add an EPUB file from Files to start reading. Books you open from other apps with Folio also appear here.")
                .font(.system(size: 15))
                .foregroundStyle(settings.theme.secondaryInk)
            Button("Add a Book") { isImporterPresented = true }
                .buttonStyle(.glassProminent)
                .padding(.top, 6)
        }
        .foregroundStyle(settings.theme.ink)
        .frame(maxWidth: 380, alignment: .leading)
    }
}

private struct ReadingNow: View {
    enum Style { case spread, card }

    let book: BookRecord
    let cover: UIImage?
    let style: Style
    let onOpen: () -> Void

    @Environment(ReaderSettings.self) private var settings

    var body: some View {
        switch style {
        case .spread:
            VStack(spacing: 22) {
                Button(action: onOpen) {
                    CoverView(book: book, image: cover)
                        .frame(height: 300)
                }
                .buttonStyle(.plain)
                VStack(spacing: 6) {
                    Text(book.title)
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(book.author)
                        .font(.system(size: 15))
                        .foregroundStyle(settings.theme.secondaryInk)
                }
                progress
                    .frame(width: 220)
                Button(action: onOpen) {
                    Text(book.progress > 0 ? "Continue Reading" : "Start Reading")
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
            .foregroundStyle(settings.theme.ink)
        case .card:
            HStack(alignment: .center, spacing: 18) {
                Button(action: onOpen) {
                    CoverView(book: book, image: cover)
                        .frame(width: 112)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reading Now")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(settings.theme.secondaryInk)
                    Text(book.title)
                        .font(.system(size: 21, design: .serif))
                        .lineLimit(3)
                    Text(book.author)
                        .font(.system(size: 14))
                        .foregroundStyle(settings.theme.secondaryInk)
                        .lineLimit(1)
                    progress
                        .padding(.top, 6)
                    Button(action: onOpen) {
                        Text(book.progress > 0 ? "Continue" : "Start Reading")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.glassProminent)
                        .padding(.top, 8)
                }
            }
            .foregroundStyle(settings.theme.ink)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }

    private var progress: some View {
        VStack(alignment: style == .spread ? .center : .leading, spacing: 6) {
            ProgressBar(value: book.progress, theme: settings.theme)
            Text(book.progress > 0 ? "\(Int((book.progress * 100).rounded()))% read" : "Not started")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(settings.theme.secondaryInk)
        }
    }
}

private struct BookTile: View {
    let book: BookRecord
    let cover: UIImage?
    let theme: ReaderTheme
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                CoverView(book: book, image: cover)
                Text(book.title)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(book.author)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondaryInk)
                    .lineLimit(1)
                if book.progress > 0 {
                    ProgressBar(value: book.progress, theme: theme)
                        .padding(.top, 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AddBookTile: View {
    let theme: ReaderTheme
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(theme.secondaryInk.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(theme.secondaryInk)
                    }
                Text("Add a Book")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(theme.secondaryInk)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a book")
    }
}

private struct ProgressBar: View {
    let value: Double
    let theme: ReaderTheme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.ink.opacity(0.12))
                Capsule().fill(Color.accentColor)
                    .frame(width: max(proxy.size.width * value, value > 0 ? 3 : 0))
            }
        }
        .frame(height: 3)
    }
}
