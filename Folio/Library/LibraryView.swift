import SwiftUI
import UniformTypeIdentifiers

/// Open, the library spreads across the fold: the current book on the left page, the shelf on the right.
/// Closed, it is a single column: the book you are reading, then a row of covers.
///
/// "Add a Book" is a toolbar item, so on the Duo it moves into the vertical bar next to the clock.
struct LibraryView: View {
    var onOpen: (BookRecord) -> Void

    @Environment(LibraryStore.self) private var library
    @Environment(ReaderSettings.self) private var settings
    @Environment(\.simulatedCreaseWidth) private var simulatedCreaseWidth

    @State private var isSpread = false
    @State private var isImporterPresented = false
    @State private var pendingRemoval: BookRecord?

    var body: some View {
        NavigationStack {
            Group {
                if isSpread {
                    GeometryReader { proxy in
                        openLayout(FoldLayout(proxy: proxy, simulatedCreaseWidth: simulatedCreaseWidth))
                    }
                } else {
                    closedLayout
                }
            }
            .background(settings.theme.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if library.isImporting {
                        ProgressView()
                    } else {
                        Button("Add a Book", systemImage: "plus") { isImporterPresented = true }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(settings.theme.colorScheme, for: .navigationBar)
        }
        .onGeometryChange(for: Bool.self) { proxy in
            FoldLayout.isSpread(proxy.size)
        } action: { spread in
            isSpread = spread
        }
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
                    ReadingNow(book: book, cover: library.cover(for: book)) { onOpen(book) }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 40)
            .frame(width: fold.leftPage.width, height: fold.size.height)

            VStack(alignment: .leading, spacing: 18) {
                title
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 18, alignment: .top), count: 3),
                        alignment: .leading,
                        spacing: 26
                    ) {
                        ForEach(library.books) { book in
                            BookTile(book: book, cover: library.cover(for: book), theme: settings.theme) {
                                onOpen(book)
                            }
                            .contextMenu { removeButton(for: book) }
                        }
                        AddCover(theme: settings.theme) { isImporterPresented = true }
                    }
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
        let others = library.books.filter { $0.id != library.recentBook?.id }
        return ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                title
                    .padding(.bottom, -12)
                if let book = library.recentBook {
                    ContinueReading(book: book, cover: library.cover(for: book), theme: settings.theme) {
                        onOpen(book)
                    }
                } else {
                    emptyState
                }

                if !others.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Books")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundStyle(settings.theme.ink)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3),
                            spacing: 20
                        ) {
                            ForEach(others) { book in
                                ShelfCover(book: book, cover: library.cover(for: book), theme: settings.theme) {
                                    onOpen(book)
                                }
                                .contextMenu { removeButton(for: book) }
                            }
                            AddCover(theme: settings.theme) { isImporterPresented = true }
                        }
                    }
                } else if library.recentBook != nil {
                    addPrompt
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Pieces

    private var title: some View {
        Text("Library")
            .font(.system(size: 34, weight: .semibold, design: .serif))
            .foregroundStyle(settings.theme.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private func removeButton(for book: BookRecord) -> some View {
        Button("Remove from Library", systemImage: "trash", role: .destructive) {
            pendingRemoval = book
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

/// The open library's left page: the current book, large and centred.
private struct ReadingNow: View {
    let book: BookRecord
    let cover: UIImage?
    let onOpen: () -> Void

    @Environment(ReaderSettings.self) private var settings

    var body: some View {
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
            VStack(spacing: 6) {
                ProgressBar(value: book.progress, theme: settings.theme)
                Text(progressLabel(book))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(settings.theme.secondaryInk)
            }
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
    }
}

/// The closed library's first row: the cover beside the title, progress and a button to carry on.
private struct ContinueReading: View {
    let book: BookRecord
    let cover: UIImage?
    let theme: ReaderTheme
    let onOpen: () -> Void

    private let coverWidth: CGFloat = 124

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Button(action: onOpen) {
                CoverView(book: book, image: cover)
                    .frame(width: coverWidth)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(book.title), \(book.author)")

            VStack(alignment: .leading, spacing: 0) {
                Text("Reading Now")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondaryInk)
                Text(book.title)
                    .font(.system(size: 22, design: .serif))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .padding(.top, 6)
                Text(book.author)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.secondaryInk)
                    .lineLimit(1)
                    .padding(.top, 4)
                Spacer(minLength: 12)
                ProgressBar(value: book.progress, theme: theme)
                Text(progressLabel(book))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(theme.secondaryInk)
                    .padding(.top, 6)
                Button(action: onOpen) {
                    Text(book.progress > 0 ? "Continue" : "Start Reading")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glassProminent)
                .padding(.top, 14)
            }
            .frame(height: coverWidth * 1.5, alignment: .topLeading)
        }
    }
}

private func progressLabel(_ book: BookRecord) -> String {
    book.progress > 0 ? "\(Int((book.progress * 100).rounded()))% read" : "Not started"
}

/// A cover on the closed library's shelf. The cover already carries the title, so there is no caption.
private struct ShelfCover: View {
    let book: BookRecord
    let cover: UIImage?
    let theme: ReaderTheme
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                CoverView(book: book, image: cover)
                if book.progress > 0 {
                    ProgressBar(value: book.progress, theme: theme)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(book.title), \(book.author)")
    }
}

/// A cover with its title and author underneath, for the open library's grid.
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

private struct AddCover: View {
    let theme: ReaderTheme
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.secondaryInk.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(theme.secondaryInk)
                }
                .contentShape(Rectangle())
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
