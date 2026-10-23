import SwiftUI

@main
struct FolioApp: App {
    @State private var library = LibraryStore()
    @State private var settings = ReaderSettings()

    var body: some Scene {
        WindowGroup {
            DeviceRoot {
                RootView()
            }
            .environment(library)
            .environment(settings)
            .onOpenURL { url in
                Task { await library.importBooks(from: [url]) }
            }
        }
    }
}

/// Wraps the app in the Duo harness when debugging with `FOLIO_DUO=1`, and reads the real hinge otherwise.
struct DeviceRoot<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        #if DEBUG
        if DebugFlags.duoHarness {
            DuoHarness { content }
        } else {
            content.modifier(HingeReader())
        }
        #else
        content.modifier(HingeReader())
        #endif
    }
}

struct RootView: View {
    @Environment(LibraryStore.self) private var library
    @State private var openBookID: UUID?

    var body: some View {
        ZStack {
            if let id = openBookID, let book = library.book(with: id) {
                ReaderView(book: book) {
                    withAnimation(.smooth(duration: 0.35)) { openBookID = nil }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.015)))
                .zIndex(1)
            } else {
                LibraryView { book in
                    withAnimation(.smooth(duration: 0.35)) { openBookID = book.id }
                }
                .transition(.opacity)
            }
        }
        .task {
            await library.prepare()
            #if DEBUG
            if DebugFlags.openBook, openBookID == nil {
                openBookID = library.recentBook?.id
            }
            #endif
        }
    }
}
