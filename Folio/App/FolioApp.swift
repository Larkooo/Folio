import Observation
import SwiftUI
import UIKit

/// The app starts from UIKit so the root view controller can opt out of the Duo's vertical bar while a
/// book is open (`preferredVerticalBarBehavior`, which SwiftUI does not expose). Config/Info.plist names
/// `SceneDelegate` as the scene delegate.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private let library = LibraryStore()
    private let settings = ReaderSettings()
    private let presentation = Presentation()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let root = DeviceRoot { RootView() }
            .environment(library)
            .environment(settings)
            .environment(presentation)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootHostingController(rootView: AnyView(root), presentation: presentation)
        window.makeKeyAndVisible()
        self.window = window
        importBooks(from: connectionOptions.urlContexts)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        importBooks(from: URLContexts)
    }

    private func importBooks(from contexts: Set<UIOpenURLContext>) {
        let urls = contexts.map(\.url).filter(\.isFileURL)
        guard !urls.isEmpty else { return }
        Task { await library.importBooks(from: urls) }
    }
}

/// App-wide presentation state that UIKit needs to see.
@MainActor
@Observable
final class Presentation {
    /// True while a book fills the screen.
    var isReading = false
}

final class RootHostingController: UIHostingController<AnyView> {
    private let presentation: Presentation

    init(rootView: AnyView, presentation: Presentation) {
        self.presentation = presentation
        super.init(rootView: rootView)
        observePresentation()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// A page of a book is a fixed layout, so the reader takes the whole width and the status bar returns
    /// to the top edge. The library keeps the system's vertical bar.
    @available(iOS 27.1, *)
    override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
        presentation.isReading ? .disabled : .automatic
    }

    private func observePresentation() {
        withObservationTracking {
            _ = presentation.isReading
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if #available(iOS 27.1, *) {
                    self.setNeedsUpdateOfVerticalBarConfiguration()
                }
                self.observePresentation()
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
    @Environment(Presentation.self) private var presentation
    @State private var openBookID: UUID?

    var body: some View {
        ZStack {
            #if DEBUG
            GeometryProbe()
            #endif
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
        .onChange(of: openBookID) { _, id in
            presentation.isReading = id != nil
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
