#if DEBUG
import SwiftUI

/// Launch-time switches for simulator testing. Pass them to `simctl launch` with a `SIMCTL_CHILD_` prefix.
enum DebugFlags {
    private static var environment: [String: String] { ProcessInfo.processInfo.environment }

    /// Render the app inside a simulated iPhone Duo (best on a 13-inch iPad simulator).
    static var duoHarness: Bool { environment["FOLIO_DUO"] == "1" }
    /// `open`, `half` or `closed`.
    static var posture: String? { environment["FOLIO_POSTURE"] }
    /// Open the most recent book at launch.
    static var openBook: Bool { environment["FOLIO_OPEN"] == "1" }
    /// Jump to this page (zero-based) once the book is laid out.
    static var page: Int? { environment["FOLIO_PAGE"].flatMap(Int.init) }
    /// Show the reader controls at launch.
    static var chrome: Bool { environment["FOLIO_CHROME"] == "1" }
    /// `contents` or `appearance`.
    static var panel: String? { environment["FOLIO_PANEL"] }
    /// A `ReaderTheme` raw value.
    static var theme: String? { environment["FOLIO_THEME"] }
}

/// Stands in for the iPhone Duo until the iOS 27.1 simulator runtime is installed. It renders the app at
/// the Duo's point sizes (inner 951 × 669 open, outer 466 × 678 closed) and simulates the crease.
struct DuoHarness<Content: View>: View {
    enum Posture: String, CaseIterable, Identifiable {
        case closed, half, open

        var id: Self { self }

        var label: String {
            switch self {
            case .closed: "Closed"
            case .half: "Half open"
            case .open: "Open"
            }
        }
    }

    @State private var posture: Posture
    private let content: Content

    private static var innerSize: CGSize { CGSize(width: 951, height: 669) }
    private static var outerSize: CGSize { CGSize(width: 466, height: 678) }
    private static var creaseWidth: CGFloat { 6 }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        _posture = State(initialValue: DebugFlags.posture.flatMap(Posture.init) ?? .open)
    }

    var body: some View {
        let isOpen = posture != .closed
        let size = isOpen ? Self.innerSize : Self.outerSize
        let radius: CGFloat = isOpen ? 30 : 44

        VStack(spacing: 28) {
            content
                .environment(\.foldContext, foldContext)
                .environment(\.simulatedCreaseWidth, isOpen ? Self.creaseWidth : nil)
                .safeAreaPadding(isOpen
                    ? EdgeInsets(top: 22, leading: 0, bottom: 16, trailing: 0)
                    : EdgeInsets(top: 50, leading: 0, bottom: 24, trailing: 0))
                .frame(width: size.width, height: size.height)
                .overlay {
                    if isOpen {
                        creaseHighlight
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .padding(9)
                .background(
                    RoundedRectangle(cornerRadius: radius + 9, style: .continuous)
                        .fill(Color(white: 0.05))
                )

            HStack(spacing: 10) {
                ForEach(Posture.allCases) { option in
                    Button(option.label) {
                        posture = option
                    }
                    .buttonStyle(.glass)
                    .tint(option == posture ? .accentColor : nil)
                    .fontWeight(option == posture ? .semibold : .regular)
                }
            }
            .environment(\.colorScheme, .dark)

            Text("\(Int(size.width)) × \(Int(size.height)) pt")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.14).ignoresSafeArea())
    }

    private var foldContext: FoldContext {
        switch posture {
        case .closed: FoldContext(status: .closed, angle: 0)
        case .half: FoldContext(status: .partiallyOpen, angle: 125)
        case .open: FoldContext(status: .fullyOpen, angle: 180)
        }
    }

    /// A faint line where the hinge sits, so it is obvious which content crosses it.
    private var creaseHighlight: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.08), .white.opacity(0.06), .black.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: Self.creaseWidth + 4)
            .allowsHitTesting(false)
    }
}
#endif
